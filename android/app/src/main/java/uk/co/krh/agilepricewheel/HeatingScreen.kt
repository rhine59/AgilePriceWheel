package uk.co.krh.agilepricewheel

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Dialog
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.lifecycle.repeatOnLifecycle
import kotlinx.coroutines.delay
import org.json.JSONObject
import java.time.Instant
import java.time.LocalDate
import java.util.Locale

internal val HeatingInfo = Color(0xFF82B9FF)
internal val HeatingOn = Color(0xFFFF7272)
internal val HeatingOff = Color(0xFF65D98A)

@Composable fun HeatingScreen(vm: HeatingViewModel, settings: AppSettings) {
    val state by vm.state.collectAsState()
    val owner = LocalLifecycleOwner.current
    var showHistory by remember { mutableStateOf(false) }
    var week by remember { mutableStateOf<String?>(null) }
    LaunchedEffect(owner, state.address, state.keyConfigured) {
        owner.lifecycle.repeatOnLifecycle(Lifecycle.State.STARTED) {
            while (true) { vm.poll(); delay(30_000) }
        }
    }
    HeatingPanel(state, settings, vm::reload, vm::savePolicy, vm::automation,
        { on, off -> vm.controller.selectPrices(on, off) }, { vm.controller.copySettings(settings) },
        { showHistory = true; week = null; vm.history() })
    if (showHistory) Dialog(onDismissRequest = { showHistory = false }) {
        Surface(shape = MaterialTheme.shapes.large, modifier = Modifier.fillMaxWidth().fillMaxHeight(.94f)) {
            HeatingHistoryPanel(state, week, { selected -> week = selected; vm.history(selected) }, { showHistory = false })
        }
    }
}

@Composable fun HeatingPanel(s: HeatingUiState, settings: AppSettings, onReload: () -> Unit, onSave: () -> Unit,
    onAutomation: (Boolean) -> Unit, onPrices: (Double, Double) -> Unit, onCopy: () -> Unit, onHistory: () -> Unit) {
    var now by remember { mutableStateOf(Instant.now()) }
    LaunchedEffect(Unit) { while (true) { now = Instant.now(); delay(5_000) } }
    var confirmEnable by remember { mutableStateOf(false) }
    var confirmSave by remember { mutableStateOf(false) }
    val editable = !s.busy && !s.needsReload && s.policy != null
    val fresh = freshHeatingCheck(s.status, s.fetchedAt, now)
    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Text("Agile heating", style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.Bold)
        HeatingStateLine("Heating policy", heatingPolicyState(s.status, s.fetchedAt, now), "heating-policy")
        HeatingStateLine("Heating state", heatingReportedState(s.status, s.fetchedAt, now), "heating-state")
        val observation = s.status?.optJSONObject("heating_control")?.optJSONObject("observation")
        if (observation?.boolOrNull("sensor_candidate_fresh") == false)
            Text("Heating state is Homely’s last report; its room sample is old.", color = HeatingInfo)
        Text(s.message, color = if (s.error) HeatingOn else HeatingInfo, modifier = Modifier.testTag("heating-message"))
        if (s.busy) LinearProgressIndicator(Modifier.fillMaxWidth())
        ElevatedCard(Modifier.fillMaxWidth()) { Column(Modifier.padding(12.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                Text("Automation")
                Switch(checked = s.automation?.boolOrNull("enabled") == true, onCheckedChange = { enabled ->
                    if (enabled) confirmEnable = true else onAutomation(false)
                }, enabled = !s.busy && s.keyConfigured && (s.automation?.boolOrNull("enabled") == true ||
                    (!s.needsReload && fresh && s.automation?.boolOrNull("can_enable") == true)), modifier = Modifier.testTag("automation-switch"))
            }
            if (s.automation == null) Text("Automation state unknown. Reload to confirm.", color = HeatingInfo)
            if (s.automation?.boolOrNull("shutdown_pending") == true) Text("Shutdown pending — heating OFF is not yet confirmed.", color = HeatingOn)
            val control = s.status?.optJSONObject("heating_control")
            val phase = control?.optString("phase")
            if (phase != null) Text(when (phase) {
                "manual_change_hold" -> "Paused after a manual Homely change."
                "boost_active" -> "Price policy boost is active."
                "waiting_for_boundary" -> "Waiting for the next half-hour."
                "heating_off" -> "Price policy heating is off."
                "automation_off" -> "Automation is off."
                "recovery_required" -> "Heating recovery needs attention."
                else -> phase.replace('_', ' ')
            }, color = if (control.boolOrNull("recovery_pending") == true) HeatingOn else HeatingInfo)
            control?.textOrNull("error")?.let { Text(it, color = HeatingOn) }
            control?.optJSONArray("blockers")?.let { blockers ->
                for (i in 0 until blockers.length()) Text(blockers.getString(i), color = HeatingInfo)
            }
            if (s.keyConfigured) TextButton(onClick = { onAutomation(false) }, enabled = !s.busy) { Text("Stop automation") }
            Text("The NAS runs the policy while this app is closed. Homely manages temperature using its existing settings.", color = HeatingInfo)
        } }
        Button(onClick = onReload, enabled = !s.busy && s.keyConfigured, modifier = Modifier.fillMaxWidth()) {
            Text("Test connection / reload controller policy")
        }
        s.status?.optJSONObject("current")?.let { current ->
            Text("Effective price: ${pence(current.numberOrNull("effective_price_p"))} p/kWh", color = HeatingInfo)
            Text("Agile price: ${pence(current.numberOrNull("agile_price_p"))} p/kWh", color = HeatingInfo)
        }
        s.policy?.let { document ->
            val policy = document.getJSONObject("policy")
            PriceMenu("Heating on", s.onPrice, editable, { onPrices(it, s.offPrice) })
            PriceMenu("Heating off", s.offPrice, editable, { onPrices(s.onPrice, it) })
            Text("On at or below; off above. Rechecked at :00 and :30. Negative prices mean payment for import.", color = HeatingInfo)
            Text("Policy revision ${document.optLong("revision")}")
            Text("Controller tariff: ${policy.optString("tariff").ifEmpty { "Not configured" }}")
            Text("Electrical load: ${pence(policy.numberOrNull("load_kw"))} kW · PV array: ${pence(policy.numberOrNull("array_kwp"))} kWp")
            TextButton(onClick = onCopy, enabled = editable) { Text("Use this app’s tariff, solar site and PV settings") }
            Text("Copies to the draft. Saving applies it to the controller.", color = HeatingInfo)
            Button(onClick = { confirmSave = true }, enabled = editable && s.offPrice >= s.onPrice) { Text("Save policy to controller") }
            if (s.offPrice < s.onPrice) Text("Heating off must be at least Heating on.", color = HeatingOn)
        }
        OutlinedButton(onClick = onHistory, enabled = !s.busy && s.keyConfigured) { Text("Weekly heating log") }
        Text("Policy is price permission; state is Homely’s report. Missing or old data shows UNKNOWN. Effective price includes forecast solar and configured load.", color = HeatingInfo)
        Spacer(Modifier.height(12.dp))
    }
    if (confirmEnable) AlertDialog(onDismissRequest = { confirmEnable = false }, title = { Text("Enable automation?") },
        text = { Text("The controller can enable heating and start boosts during qualifying half-hour slots. Homely keeps its existing temperature settings.") },
        confirmButton = { TextButton(onClick = { confirmEnable = false; onAutomation(true) }) { Text("Enable") } },
        dismissButton = { TextButton(onClick = { confirmEnable = false }) { Text("Cancel") } })
    if (confirmSave) AlertDialog(onDismissRequest = { confirmSave = false }, title = { Text("Save heating policy?") },
        text = { Text("Apply Heating on ${pence(s.onPrice)}p and Heating off ${pence(s.offPrice)}p? An active controller uses this policy at a new half-hour decision.") },
        confirmButton = { TextButton(onClick = { confirmSave = false; onSave() }) { Text("Save") } },
        dismissButton = { TextButton(onClick = { confirmSave = false }) { Text("Cancel") } })
}

@Composable private fun HeatingStateLine(label: String, value: Boolean?, tag: String) {
    Text("$label: ${when (value) { true -> "ON"; false -> "OFF"; null -> "UNKNOWN" }}",
        color = when (value) { true -> HeatingOn; false -> HeatingOff; null -> HeatingInfo },
        style = MaterialTheme.typography.titleMedium, modifier = Modifier.testTag(tag))
}

@Composable private fun PriceMenu(label: String, value: Double, enabled: Boolean, select: (Double) -> Unit) {
    var expanded by remember { mutableStateOf(false) }
    val choices = ((-20..20).map { it.toDouble() } + value).distinct().sorted()
    Box {
        OutlinedButton(onClick = { expanded = true }, enabled = enabled, modifier = Modifier.fillMaxWidth().testTag(label)) {
            Text("$label — ${pence(value)} p/kWh")
        }
        DropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }, modifier = Modifier.heightIn(max = 300.dp)) {
            choices.forEach { choice -> DropdownMenuItem(text = { Text("${pence(choice)} p/kWh") }, onClick = { expanded = false; select(choice) }) }
        }
    }
}

@Composable fun HeatingConnectionSettings(s: HeatingUiState, save: (String, String) -> Unit) {
    var address by remember(s.address) { mutableStateOf(s.address) }
    var key by remember { mutableStateOf("") }
    Column(Modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(8.dp)) {
        HorizontalDivider(Modifier.padding(vertical = 12.dp))
        Text("Heating connection", style = MaterialTheme.typography.titleLarge)
        OutlinedTextField(address, { address = it }, label = { Text("Controller HTTPS address") }, singleLine = true, modifier = Modifier.fillMaxWidth())
        OutlinedTextField(key, { key = it }, label = { Text(if (s.keyConfigured) "Replacement key (leave blank to keep)" else "Controller key") },
            visualTransformation = PasswordVisualTransformation(), singleLine = true, modifier = Modifier.fillMaxWidth())
        Button(onClick = { save(address, key); key = "" }, enabled = !s.busy) { Text("Save connection") }
        Text("The key is encrypted using Android Keystore and excluded from backups. A different address needs its own key.", color = HeatingInfo)
        Text(s.message, color = if (s.error) HeatingOn else HeatingInfo)
    }
}

@Composable fun HeatingHistoryPanel(s: HeatingUiState, selectedWeek: String?, load: (String?) -> Unit, done: () -> Unit) {
    val d = s.history
    val week = d?.optString("week_start") ?: selectedWeek
    Column(Modifier.fillMaxSize().padding(12.dp).verticalScroll(rememberScrollState()), verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Text("Weekly heating log", style = MaterialTheme.typography.titleLarge)
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
            TextButton(onClick = done) { Text("Done") }
            TextButton(onClick = { load(week) }, enabled = !s.busy) { Text("Reload") }
        }
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
            TextButton(onClick = { week?.let { load(LocalDate.parse(it).minusWeeks(1).toString()) } },
                enabled = !s.busy && d != null && d.getString("week_start") > d.getString("oldest_week")) { Text("Previous week") }
            TextButton(onClick = { week?.let { load(LocalDate.parse(it).plusWeeks(1).toString()) } },
                enabled = !s.busy && d != null && d.getString("week_start") < d.getString("current_week")) { Text("Next week") }
        }
        if (d != null) Text("${d.getString("week_start")} – ${LocalDate.parse(d.getString("week_end")).minusDays(1)}")
        Text("Confirmed controller actions · UK time. Manual changes are not included.", color = HeatingInfo)
        if (s.busy) LinearProgressIndicator(Modifier.fillMaxWidth())
        s.historyError?.let { Text(it, color = HeatingOn) }
        d?.textOrNull("warning")?.let { Text(it, color = HeatingOn) }
        if ((d?.optInt("pending_events") ?: 0) > 0) Text("Some confirmed actions are waiting to be saved.", color = HeatingOn)
        d?.rows("sessions")?.forEach { session ->
            ElevatedCard(Modifier.fillMaxWidth()) { Column(Modifier.padding(12.dp), verticalArrangement = Arrangement.spacedBy(5.dp)) {
                Text("Heating session", fontWeight = FontWeight.Bold)
                Text("ON ${HeatingDates.time(session.textOrNull("on_at"))}", color = HeatingOn)
                Text(session.textOrNull("off_at")?.let { "OFF ${HeatingDates.time(it)}" } ?: "OFF not confirmed",
                    color = if (session.textOrNull("off_at") == null) HeatingInfo else HeatingOff)
                val seconds = session.numberOrNull("duration_seconds")?.toLong()
                Text(seconds?.let { "Duration: ${it / 3600}h ${it % 3600 / 60}m ${it % 60}s" } ?: "End unconfirmed")
                Text(heatingSessionCost(session), color = HeatingInfo)
                session.numberOrNull("estimated_energy_kwh")?.let { Text("Estimated electricity: ${String.format(Locale.UK, "%.4f", it)} kWh") }
                session.numberOrNull("on_price_p")?.let { Text("Effective rate at ON: ${pence(it)} p/kWh") }
                session.numberOrNull("off_price_p")?.let { Text("Effective rate at OFF: ${pence(it)} p/kWh") }
                session.rows("intervals").forEach { interval ->
                    Text("${HeatingDates.time(interval.textOrNull("start"))} – ${HeatingDates.time(interval.textOrNull("end"))}")
                    Text("Agile: ${pence(interval.numberOrNull("agile_price_p"))} · Effective: ${pence(interval.numberOrNull("effective_price_p"))} p/kWh")
                    Text("Assumed load: ${pence(interval.numberOrNull("load_kw"))} kW")
                }
                session.textOrNull("off_reason")?.let { Text("Stop: ${it.replace('_', ' ')}") }
            } }
        }
        if (d != null) {
            Text("Costs are estimated using configured load and forecast solar, not metered use. Sessions crossing weeks appear in each overlapping week; do not add duplicates.", color = HeatingInfo)
            Text("Individual actions", style = MaterialTheme.typography.titleMedium)
            if (d.rows("events").isEmpty()) Text("No recorded heating changes this week.", color = HeatingInfo)
            d.rows("events").forEach { event ->
                val on = event.optString("state") == "on"
                ElevatedCard(Modifier.fillMaxWidth()) { Column(Modifier.padding(10.dp)) {
                    Text("Heating ${if (on) "ON" else "OFF"}", color = if (on) HeatingOn else HeatingOff)
                    Text(HeatingDates.time(event.textOrNull("at")))
                    Text(event.optString("reason").replace('_', ' '))
                    if (event.optString("source") == "supervised_test") Text("Supervised test", color = HeatingInfo)
                    Text("Effective price: ${pence(event.numberOrNull("price_p"))} p/kWh")
                    Text("On ≤ ${pence(event.numberOrNull("on_price_p"))}p · Off > ${pence(event.numberOrNull("off_price_p"))}p")
                } }
            }
            d.textOrNull("recording_started_at")?.let { Text("Logging began ${HeatingDates.time(it)}", color = HeatingInfo) }
            Text("Retention: ${d.optInt("retention_days")} days. Times are confirmations, not consumption measurements.", color = HeatingInfo)
            if (d.optBoolean("truncated")) Text("This week has too many entries to display completely.", color = HeatingOn)
        }
    }
}

private fun pence(value: Double?): String = value?.let { String.format(Locale.UK, "%.2f", it) } ?: "Unavailable"
