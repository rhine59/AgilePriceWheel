package uk.co.krh.agilepricewheel

import org.json.JSONObject
import java.net.URI
import java.time.DayOfWeek
import java.time.Duration
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.time.temporal.TemporalAdjusters
import java.util.Locale
import javax.net.ssl.HttpsURLConnection

class HeatingFailure(val userMessage: String, val uncertainWrite: Boolean = false) : Exception(userMessage)

// The same origin is used for every request; redirects are never followed.
fun heatingOrigin(text: String): URI {
    val u = try { URI(text.trim()) } catch (_: Exception) { throw HeatingFailure("Enter a valid HTTPS controller address.") }
    if (u.scheme != "https" || u.host.isNullOrBlank() || u.rawUserInfo != null ||
        u.rawQuery != null || u.rawFragment != null || u.rawPath !in listOf("", "/") ||
        u.port !in -1..65535 || u.port == 0) throw HeatingFailure("Use HTTPS without a path, password or query.")
    return URI("https", null, u.host.lowercase(Locale.ROOT), u.port, null, null, null)
}

internal fun JSONObject.numberOrNull(name: String): Double? =
    (opt(name) as? Number)?.toDouble()?.takeIf { it.isFinite() }
internal fun JSONObject.boolOrNull(name: String): Boolean? = opt(name) as? Boolean
internal fun JSONObject.textOrNull(name: String): String? = (opt(name) as? String)?.takeIf { it.isNotEmpty() }
internal fun JSONObject.rows(name: String): List<JSONObject> {
    val array = optJSONArray(name) ?: return emptyList()
    return (0 until array.length()).map { array.getJSONObject(it) }
}

object HeatingDates {
    val london: ZoneId = ZoneId.of("Europe/London")
    fun monday(now: Instant = Instant.now()): LocalDate = now.atZone(london).toLocalDate()
        .with(TemporalAdjusters.previousOrSame(DayOfWeek.MONDAY))
    fun week(text: String): LocalDate = LocalDate.parse(text).also {
        require(it.dayOfWeek == DayOfWeek.MONDAY) { "History week must start on Monday" }
    }
    fun time(text: String?): String = try {
        DateTimeFormatter.ofPattern("EEE d MMM, HH:mm:ss z", Locale.UK).withZone(london).format(Instant.parse(text))
    } catch (_: Exception) { "Time unavailable" }
}

fun freshHeatingCheck(status: JSONObject?, fetchedAt: Instant?, now: Instant): Boolean {
    if (fetchedAt == null || Duration.between(fetchedAt, now).seconds !in 0..45) return false
    val control = status?.optJSONObject("heating_control") ?: return false
    val checked = try { Instant.parse(control.getString("last_checked_at")) } catch (_: Exception) { return false }
    return Duration.between(checked, now).seconds in 0..45
}

fun heatingPolicyState(status: JSONObject?, fetchedAt: Instant?, now: Instant): Boolean? {
    if (!freshHeatingCheck(status, fetchedAt, now) || status == null || status.boolOrNull("stale") != false ||
        status.optJSONObject("current") == null) return null
    val slot = status.optJSONObject("current")!!
    try {
        if (now.isBefore(Instant.parse(slot.getString("start"))) || !now.isBefore(Instant.parse(slot.getString("end")))) return null
    } catch (_: Exception) { return null }
    return status.boolOrNull("price_requests_heat")
}
fun heatingReportedState(status: JSONObject?, fetchedAt: Instant?, now: Instant): Boolean? {
    if (!freshHeatingCheck(status, fetchedAt, now)) return null
    val control = status?.optJSONObject("heating_control") ?: return null
    if (control.textOrNull("error") != null) return null
    return control.optJSONObject("observation")?.boolOrNull("reported_heating_on")
}

// Retain the entire latest document, including compatibility fields. Never rebuild it from phone defaults.
fun heatingPriceDraft(document: JSONObject, on: Double, off: Double): JSONObject {
    if (!on.isFinite() || !off.isFinite() || off < on) throw HeatingFailure("Heating off must be at least Heating on.")
    return JSONObject(document.toString()).also {
        it.getJSONObject("policy").put("on_price_p", on).put("off_price_p", off)
    }
}

fun heatingSessionCost(session: JSONObject): String {
    val cost = session.numberOrNull("estimated_cost_gbp")
    if (cost == null) return if (session.textOrNull("off_at") == null) "Estimated cost: end unconfirmed"
        else "Estimated cost: unavailable (missing rate/load data)"
    if (session.optString("cost_status") != "estimated") return "Estimated cost: unavailable"
    return String.format(Locale.UK, if (cost < 0) "Estimated payment: £%.4f" else "Estimated cost: £%.4f", kotlin.math.abs(cost))
}

fun interface HeatingTransport {
    fun exchange(origin: URI, token: String, path: String, body: JSONObject?): JSONObject
}

class HttpsHeatingTransport(private val open: (java.net.URL) -> HttpsURLConnection = { it.openConnection() as HttpsURLConnection }) : HeatingTransport {
    override fun exchange(origin: URI, token: String, path: String, body: JSONObject?): JSONObject {
        val connection = open(origin.resolve(path).toURL())
        connection.instanceFollowRedirects = false
        connection.connectTimeout = 15_000; connection.readTimeout = 20_000
        connection.useCaches = false
        connection.setRequestProperty("Authorization", "Bearer $token")
        connection.setRequestProperty("Accept", "application/json")
        try {
            if (body != null) {
                val bytes = body.toString().toByteArray(Charsets.UTF_8)
                connection.requestMethod = "PUT"; connection.doOutput = true
                connection.setRequestProperty("Content-Type", "application/json")
                connection.setFixedLengthStreamingMode(bytes.size)
                connection.outputStream.use { it.write(bytes) }
            }
            when (val code = connection.responseCode) {
                200 -> Unit
                401 -> throw HeatingFailure("The controller key was not accepted.")
                409 -> throw HeatingFailure(if (path.startsWith("/v1/policy")) "Policy changed elsewhere. Reload before saving."
                    else "Automation cannot be enabled until the controller is ready.")
                in 300..399 -> throw HeatingFailure("Controller redirects are refused. Check its HTTPS address.", body != null)
                else -> throw HeatingFailure("Controller request failed ($code). Reload to check its state.", body != null && code >= 500)
            }
            val bytes = connection.inputStream.use { input ->
                val out = java.io.ByteArrayOutputStream()
                val buffer = ByteArray(8192)
                while (out.size() <= 8 * 1024 * 1024) {
                    val n = input.read(buffer)
                    if (n < 0) break
                    out.write(buffer, 0, n)
                }
                out.toByteArray()
            }
            if (bytes.size > 8 * 1024 * 1024) throw HeatingFailure("Controller response is too large.", body != null)
            return JSONObject(String(bytes, Charsets.UTF_8))
        } catch (e: HeatingFailure) { throw e }
        catch (_: Exception) { throw HeatingFailure(if (body == null) "Could not contact the controller. Check the address, key and connection."
            else "Save outcome is unconfirmed. Reload controller state before trying again.", body != null) }
        finally { connection.disconnect() }
    }
}

class HeatingApi(address: String, private val token: String, private val transport: HeatingTransport = HttpsHeatingTransport()) {
    private val origin = heatingOrigin(address)
    init { if (token.isBlank() || token.any { it == '\r' || it == '\n' }) throw HeatingFailure("Enter the controller key in Settings.") }
    fun status(): JSONObject = get("status").also {
        val mode = it.getString("mode"); val enabled = it.getBoolean("control_enabled")
        if (!((mode == "automatic" && enabled) || (mode == "plan_only" && !enabled))) throw HeatingFailure("Unsupported controller mode.")
    }
    fun policy(): JSONObject = get("policy").also { it.getLong("revision"); it.getJSONObject("policy") }
    fun automation(): JSONObject = get("automation").also { it.getBoolean("enabled"); it.getBoolean("can_enable") }
    fun history(week: String? = null): JSONObject {
        val path = "/v1/history" + (week?.let { "?week=${HeatingDates.week(it)}" } ?: "")
        return transport.exchange(origin, token, path, null).also {
            val first = HeatingDates.week(it.getString("week_start"))
            require(HeatingDates.week(it.getString("week_end")) == first.plusWeeks(1))
            HeatingDates.week(it.getString("oldest_week")); HeatingDates.week(it.getString("current_week"))
            require(it.getString("timezone") == "Europe/London")
            it.getJSONArray("events")
            require(it.rows("events").all { event -> event.optString("state") in listOf("on", "off") })
            it.rows("sessions").forEach { session -> session.rows("intervals") }
        }
    }
    fun savePolicy(draft: JSONObject): JSONObject = transport.exchange(origin, token, "/v1/policy", draft)
    fun setAutomation(enabled: Boolean): JSONObject = transport.exchange(origin, token, "/v1/automation", JSONObject().put("enabled", enabled))
    private fun get(path: String) = transport.exchange(origin, token, "/v1/$path", null)
}
