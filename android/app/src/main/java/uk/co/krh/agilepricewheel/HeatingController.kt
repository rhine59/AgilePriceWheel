package uk.co.krh.agilepricewheel

import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.time.Instant

// No background heater runs on the phone. This is a client of the NAS controller only.
data class HeatingUiState(
    val address: String = "", val keyConfigured: Boolean = false, val busy: Boolean = false,
    val policy: JSONObject? = null, val status: JSONObject? = null, val automation: JSONObject? = null,
    val history: JSONObject? = null, val historyError: String? = null,
    val onPrice: Double = 0.0, val offPrice: Double = 0.0,
    val fetchedAt: Instant? = null, val needsReload: Boolean = true,
    val message: String = "Set the controller address and key in Settings.", val error: Boolean = false
)

class HeatingController(private val store: HeatingConnectionStore,
    private val transport: HeatingTransport = HttpsHeatingTransport(),
    private val io: CoroutineDispatcher = Dispatchers.IO, private val now: () -> Instant = Instant::now) {
    private val mutable = MutableStateFlow(HeatingUiState())
    val state = mutable.asStateFlow()
    private val mutex = Mutex()
    private var connection: HeatingConnection? = null
    private fun api(): HeatingApi {
        val c = connection ?: throw HeatingFailure("Set the controller address and key in Settings.")
        return HeatingApi(c.address, c.token, transport)
    }
    private suspend fun operation(block: () -> Unit) {
        if (!mutex.tryLock()) return
        mutable.value = mutable.value.copy(busy = true)
        try { withContext(io) { block() } }
        catch (e: CancellationException) { throw e }
        catch (e: Exception) {
            mutable.value = mutable.value.copy(status = null, automation = null, fetchedAt = null, needsReload = true,
                error = true, message = (e as? HeatingFailure)?.userMessage ?: "Controller data could not be read. Reload before making changes.")
        } finally { mutable.value = mutable.value.copy(busy = false); mutex.unlock() }
    }
    suspend fun initialise() = operation {
        try {
            connection = store.load()
            mutable.value = mutable.value.copy(address = connection?.address ?: "", keyConfigured = connection != null,
                message = if (connection == null) "Set the controller address and key in Settings." else "Connection saved. Test connection / reload controller policy.")
        } catch (_: Exception) { throw HeatingFailure("Saved controller key could not be unlocked. Enter it again in Settings.") }
    }
    suspend fun saveConnection(address: String, enteredKey: String) = operation {
        val canonical = heatingOrigin(address).toString()
        val token = enteredKey.trim().ifEmpty {
            connection?.takeIf { it.address == canonical }?.token ?: throw HeatingFailure("Enter a key for this controller address.")
        }
        HeatingApi(canonical, token, transport)
        val replacement = HeatingConnection(canonical, token)
        try { store.save(replacement) } catch (_: Exception) { throw HeatingFailure("Could not save the controller key securely.") }
        connection = replacement
        mutable.value = HeatingUiState(address = canonical, keyConfigured = true, busy = true,
            message = "Connection saved securely. Test connection / reload controller policy.")
    }
    private fun refreshAll(message: String = "Controller policy loaded.") {
        val api = api()
        val policy = api.policy(); val status = api.status(); val automation = api.automation()
        if (status.optLong("revision", -1) != policy.getLong("revision")) throw HeatingFailure("Policy changed during refresh. Reload to get a consistent view.")
        val p = policy.getJSONObject("policy")
        val on = p.numberOrNull("on_price_p") ?: throw HeatingFailure("Controller returned an invalid on price.")
        val off = p.numberOrNull("off_price_p") ?: throw HeatingFailure("Controller returned an invalid off price.")
        mutable.value = mutable.value.copy(policy = policy, status = status, automation = automation,
            onPrice = on, offPrice = off, fetchedAt = now(), needsReload = false, message = message, error = false)
    }
    suspend fun reload() = operation { refreshAll() }
    suspend fun poll() = operation {
        if (connection == null || mutable.value.policy == null || mutable.value.needsReload) return@operation
        val api = api(); val status = api.status(); val automation = api.automation()
        val changed = status.optLong("revision", -1) != mutable.value.policy!!.getLong("revision")
        mutable.value = mutable.value.copy(status = status, automation = automation, fetchedAt = now(), needsReload = changed,
            message = if (changed) "Policy changed elsewhere. Reload before saving." else mutable.value.message,
            error = changed || mutable.value.error)
    }
    fun selectPrices(on: Double = state.value.onPrice, off: Double = state.value.offPrice) {
        if (state.value.busy) return
        mutable.value = state.value.copy(onPrice = on, offPrice = off)
    }
    fun copySettings(s: AppSettings) {
        if (state.value.busy || state.value.needsReload) return
        if (s.latitude == null || s.longitude == null) {
            mutable.value = state.value.copy(message = "Choose a solar site in Settings first.", error = true); return
        }
        val draft = JSONObject(state.value.policy!!.toString())
        draft.getJSONObject("policy").apply {
            put("product", s.productCode); put("tariff", s.tariffCode); put("latitude", s.latitude); put("longitude", s.longitude)
            put("array_kwp", if (s.pvInstalled) s.effectiveKwp else 0.0); put("loss_percent", s.systemLossPercent)
            put("inverter_kw", s.inverterMaxKw); put("load_kw", s.loadKw)
        }
        mutable.value = state.value.copy(policy = draft, message = "App settings copied to the draft. Save policy to apply them.", error = false)
    }
    suspend fun savePolicy() = operation {
        val s = state.value
        if (s.needsReload || s.policy == null) throw HeatingFailure("Reload controller policy before saving.")
        val draft = heatingPriceDraft(s.policy, s.onPrice, s.offPrice)
        api().savePolicy(draft) // One write only. An uncertain result requires a read, never automatic replay.
        try { refreshAll("Policy saved. A new half-hour decision will use it.") }
        catch (_: Exception) { throw HeatingFailure("Policy save returned, but readback failed. Reload to confirm the saved policy.", true) }
    }
    suspend fun setAutomation(enabled: Boolean) = operation {
        val s = state.value
        if (enabled && (s.needsReload || s.automation?.boolOrNull("can_enable") != true))
            throw HeatingFailure("Reload and check that the controller is ready before enabling automation.")
        val result = api().setAutomation(enabled)
        mutable.value = state.value.copy(automation = result, status = null, fetchedAt = null,
            message = if (enabled) "Automation ON requested. Waiting for controller confirmation." else "Automation OFF requested. Checking shutdown.", error = false)
        try { refreshAll(if (enabled) "Automation ON saved; qualifying slots can start heating."
            else "Automation OFF saved. Check shutdown status below.") }
        catch (_: Exception) { throw HeatingFailure("Automation request returned, but readback failed. Reload to confirm its state.", true) }
    }
    suspend fun loadHistory(week: String? = null) {
        if (!mutex.tryLock()) return
        mutable.value = state.value.copy(busy = true, historyError = null, history = null)
        try { val history = withContext(io) { api().history(week) }; mutable.value = state.value.copy(history = history) }
        catch (e: CancellationException) { throw e }
        catch (e: Exception) { mutable.value = state.value.copy(historyError = (e as? HeatingFailure)?.userMessage ?: "Could not read heating history. Try reloading.") }
        finally { mutable.value = state.value.copy(busy = false); mutex.unlock() }
    }
}
