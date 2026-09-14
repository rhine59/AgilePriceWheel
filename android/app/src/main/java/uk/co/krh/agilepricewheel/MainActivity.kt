package uk.co.krh.agilepricewheel

import android.Manifest
import android.content.pm.PackageManager
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.core.content.ContextCompat
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.google.android.gms.location.LocationServices
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import kotlin.math.atan2

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent { MaterialTheme(colorScheme = darkColorScheme()) { AgilePriceWheelApp() } }
    }
}

enum class Page(val label: String, val icon: ImageVector, val pvOnly: Boolean = false) {
    Prices("Prices", Icons.Default.Bolt, false), Solar("Solar", Icons.Default.WbSunny, false),
    PV("PV", Icons.Default.ElectricBolt, true), Net("Net", Icons.Default.CurrencyPound, true),
    Save("Save", Icons.Default.Savings, true), Settings("Settings", Icons.Default.Tune, false), Guide("Guide", Icons.Default.MenuBook, false)
}

@Composable fun AgilePriceWheelApp(vm: MainViewModel = viewModel()) {
    val settings by vm.settings.collectAsStateWithLifecycle(); val rates by vm.rates.collectAsStateWithLifecycle(); val solar by vm.solar.collectAsStateWithLifecycle()
    val loading by vm.loading.collectAsStateWithLifecycle(); val error by vm.error.collectAsStateWithLifecycle()
    val derived = remember(rates, solar, settings) { derivePeriods(rates, solar, settings) }
    var page by remember { mutableStateOf(Page.Prices) }; var selected by remember { mutableIntStateOf(0) }
    val visible = Page.entries.filter { !it.pvOnly || settings.pvInstalled }
    LaunchedEffect(settings.pvInstalled) { if (page.pvOnly && !settings.pvInstalled) page = Page.Solar }
    LaunchedEffect(Unit) { vm.refresh() }

    Scaffold(
        containerColor = Color(0xFF07111F),
        bottomBar = { NavigationBar(containerColor = Color(0xFF0B1626)) { visible.forEach { p -> NavigationBarItem(selected = p == page, onClick = { page = p }, icon = { Icon(p.icon, p.label) }, label = { Text(p.label, maxLines = 1) }) } } }
    ) { padding ->
        BoxWithConstraints(Modifier.fillMaxSize().padding(padding)) {
            val maxContent = if (maxWidth > 700.dp) 760.dp else maxWidth
            Column(Modifier.widthIn(max = maxContent).fillMaxHeight().align(Alignment.TopCenter).padding(horizontal = if (maxWidth < 380.dp) 8.dp else 16.dp)) {
                Header(page, loading, onNow = {
                    vm.updateSettings { it.copy(selectedDate = java.time.LocalDate.now()) }; vm.refresh()
                    val now = Instant.now(); selected = rates.indexOfFirst { !now.isBefore(it.validFrom) && now.isBefore(it.validTo) }.coerceAtLeast(0)
                })
                error?.let { Text(it, color = MaterialTheme.colorScheme.error, modifier = Modifier.padding(8.dp)) }
                when (page) {
                    Page.Prices -> MetricPage("Octopus Agile Prices", derived, selected, { selected = it }, { it.agilePence }, "p/kWh")
                    Page.Solar -> MetricPage("Solar Forecast", derived, selected, { selected = it }, { it.ghiWm2 }, "W/m²")
                    Page.PV -> MetricPage("PV Forecast", derived, selected, { selected = it }, { it.pvKwh }, "kWh")
                    Page.Net -> MetricPage("Net Electricity Price", derived, selected, { selected = it }, { it.netPencePerKwh }, "p/kWh", derived.getOrNull(selected)?.let { "PV saving %.2f p".format(it.savingPence) })
                    Page.Save -> MetricPage("Cost Savings", derived, selected, { selected = it }, { it.savingPence }, "p", derived.getOrNull(selected)?.let { "Avoided import %.3f kWh".format(it.avoidedImportKwh) })
                    Page.Settings -> SettingsPage(settings, vm)
                    Page.Guide -> GuidePage()
                }
            }
        }
    }
}

@Composable private fun Header(page: Page, loading: Boolean, onNow: () -> Unit) {
    Row(Modifier.fillMaxWidth().padding(top = 8.dp, bottom = 4.dp), verticalAlignment = Alignment.CenterVertically) {
        Text(page.label, style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold, modifier = Modifier.weight(1f))
        if (page !in listOf(Page.Settings, Page.Guide)) TextButton(onClick = onNow) { Text("Now") }
        if (loading) CircularProgressIndicator(Modifier.size(22.dp), strokeWidth = 2.dp)
    }
}

@Composable private fun MetricPage(title: String, data: List<DerivedPeriod>, selected: Int, onSelect: (Int)->Unit, value: (DerivedPeriod)->Double, unit: String, extra: String? = null) {
    val item = data.getOrNull(selected)
    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()), horizontalAlignment = Alignment.CenterHorizontally) {
        Text(title, style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.Bold)
        if (data.isEmpty()) Text("No data loaded", modifier = Modifier.padding(32.dp)) else {
            HalfHourWheel(data.map(value), selected, onSelect, Modifier.fillMaxWidth().aspectRatio(1f).widthIn(max = 520.dp))
            item?.let {
                Text("%.2f %s".format(value(it), unit), style = MaterialTheme.typography.headlineMedium)
                Text(formatPeriod(it.validFrom, it.validTo)); extra?.let { x -> Text(x, color = Color(0xFFFFA726)) }
                Spacer(Modifier.height(8.dp))
                ElevatedCard(Modifier.fillMaxWidth()) { Column(Modifier.padding(14.dp)) {
                    Text("Selected half-hour", fontWeight = FontWeight.Bold)
                    Text("Agile price %.2f p/kWh".format(it.agilePence)); Text("Solar %.1f W/m²".format(it.ghiWm2)); Text("PV %.3f kWh".format(it.pvKwh)); Text("Load %.3f kWh".format(it.loadKwh)); Text("PV saving %.2f p".format(it.savingPence))
                } }
            }
        }
    }
}

@Composable private fun HalfHourWheel(values: List<Double>, selected: Int, onSelect: (Int)->Unit, modifier: Modifier) {
    val max = values.maxOfOrNull { kotlin.math.abs(it) }?.coerceAtLeast(1.0) ?: 1.0
    Canvas(modifier.pointerInput(values.size) { detectTapGestures { p ->
        val c = Offset(size.width/2f, size.height/2f); var angle = Math.toDegrees(atan2((p.y-c.y).toDouble(), (p.x-c.x).toDouble())).toFloat()+90f; if (angle < 0) angle += 360f
        onSelect(((angle / 360f) * values.size).toInt().coerceIn(0, values.lastIndex))
    } }) {
        if (values.isEmpty()) return@Canvas
        val sweep = 360f / values.size; val stroke = size.minDimension * 0.20f; val inset = stroke/2 + 8
        values.forEachIndexed { i, v ->
            val ratio = (kotlin.math.abs(v)/max).toFloat(); val color = if (v < 0) Color(0xFF1565C0) else Color.hsv(120f*(1-ratio), .75f, .9f)
            drawArc(color, -90f+i*sweep, sweep-0.6f, false, topLeft=Offset(inset,inset), size=Size(size.width-2*inset,size.height-2*inset), style=androidx.compose.ui.graphics.drawscope.Stroke(stroke))
            if (i == selected) drawArc(Color.White, -90f+i*sweep, sweep-0.6f, false, topLeft=Offset(inset,inset), size=Size(size.width-2*inset,size.height-2*inset), style=androidx.compose.ui.graphics.drawscope.Stroke(3.dp.toPx()))
        }
    }
}

@Composable private fun SettingsPage(s: AppSettings, vm: MainViewModel) {
    val context = LocalContext.current
    val fused = remember { LocationServices.getFusedLocationProviderClient(context) }
    val launcher = rememberLauncherForActivityResult(ActivityResultContracts.RequestMultiplePermissions()) { result ->
        if (result.values.any { it }) try { fused.lastLocation.addOnSuccessListener { l -> if (l != null) vm.setCurrentSite(l.latitude, l.longitude) } } catch (_: SecurityException) {}
    }
    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState())) {
        Text("App Settings", style=MaterialTheme.typography.headlineSmall, fontWeight=FontWeight.Bold)
        Row(verticalAlignment=Alignment.CenterVertically) { Text("Solar PV panels installed", Modifier.weight(1f)); Switch(s.pvInstalled, { vm.updateSettings { x -> x.copy(pvInstalled=it) } }) }
        OutlinedTextField(s.siteName, { name -> vm.updateSettings { it.copy(siteName=name) } }, label={Text("Solar site name")}, modifier=Modifier.fillMaxWidth())
        Button(onClick={
            val fine = ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED
            if (fine) try { fused.lastLocation.addOnSuccessListener { l -> if (l != null) vm.setCurrentSite(l.latitude,l.longitude) } } catch (_: SecurityException) {}
            else launcher.launch(arrayOf(Manifest.permission.ACCESS_FINE_LOCATION, Manifest.permission.ACCESS_COARSE_LOCATION))
        }) { Icon(Icons.Default.MyLocation,null); Spacer(Modifier.width(6.dp)); Text("Use Current Location") }
        if (s.latitude != null) Text("${s.siteName}: %.5f, %.5f".format(s.latitude,s.longitude))
        NumberSetting("Rated peak power", s.ratedKwp, "kWp") { vm.updateSettings { x -> x.copy(ratedKwp=it) } }
        NumberSetting("Inverter maximum AC output", s.inverterMaxKw, "kW") { vm.updateSettings { x -> x.copy(inverterMaxKw=it) } }
        NumberSetting("Estimated system losses", s.systemLossPercent, "%") { vm.updateSettings { x -> x.copy(systemLossPercent=it) } }
        NumberSetting("Optimiser load", s.loadKw, "kW") { vm.updateSettings { x -> x.copy(loadKw=it) } }
        Button(onClick={vm.refresh()}, modifier=Modifier.padding(vertical=12.dp)) { Text("Refresh prices and solar forecast") }
        Text("When PV is off, PV Forecast, Net Electricity Price and Cost Savings are hidden. Saved PV settings are retained.", style=MaterialTheme.typography.bodySmall)
    }
}

@Composable private fun NumberSetting(label:String, value:Double, unit:String, update:(Double)->Unit) { var text by remember(value) { mutableStateOf(value.toString()) }; OutlinedTextField(text, { text=it; it.toDoubleOrNull()?.let(update) }, label={Text(label)}, suffix={Text(unit)}, modifier=Modifier.fillMaxWidth().padding(top=6.dp)) }

@Composable private fun GuidePage() { Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState())) { Text("User Guide", style=MaterialTheme.typography.headlineSmall, fontWeight=FontWeight.Bold); Text("Prices • Solar • PV • Net • Save • Settings • Guide", modifier=Modifier.padding(vertical=8.dp)); Text("PV, Net and Save are hidden when Solar PV panels installed is off. Now returns metric pages to today's current half-hour. Cost Savings is avoided grid-import cost: min(PV energy, configured load energy) × Agile price. Net uses forecast PV to reduce expected grid import. Current Location is opt-in and the resolved site label remains editable.") } }

private fun formatPeriod(from: Instant, to: Instant): String { val f=DateTimeFormatter.ofPattern("HH:mm").withZone(ZoneId.of("Europe/London")); return "${f.format(from)}–${f.format(to)}" }
