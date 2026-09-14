package uk.co.krh.agilepricewheel

import java.time.Instant
import java.time.LocalDate

data class AgileRate(val validFrom: Instant, val validTo: Instant, val pencePerKwh: Double)
data class SolarPeriod(val validFrom: Instant, val validTo: Instant, val ghiWm2: Double)
data class DerivedPeriod(
    val validFrom: Instant,
    val validTo: Instant,
    val agilePence: Double,
    val ghiWm2: Double,
    val pvKwh: Double,
    val loadKwh: Double,
    val avoidedImportKwh: Double,
    val gridImportKwh: Double,
    val netPencePerKwh: Double,
    val savingPence: Double
)

data class AppSettings(
    val selectedDate: LocalDate = LocalDate.now(),
    val region: String = "G",
    val tariffCode: String = "E-1R-AGILE-24-10-01-G",
    val productCode: String = "AGILE-24-10-01",
    val pvInstalled: Boolean = true,
    val siteName: String = "",
    val latitude: Double? = null,
    val longitude: Double? = null,
    val ratedKwp: Double = 5.0,
    val panelCount: Int = 0,
    val panelWatts: Double = 0.0,
    val inverterMaxKw: Double = 5.0,
    val systemLossPercent: Double = 14.0,
    val loadKw: Double = 3.0
) {
    val effectiveKwp: Double get() = if (ratedKwp > 0) ratedKwp else panelCount * panelWatts / 1000.0
}

fun derivePeriods(rates: List<AgileRate>, solar: List<SolarPeriod>, settings: AppSettings): List<DerivedPeriod> = rates.map { rate ->
    val hours = (rate.validTo.epochSecond - rate.validFrom.epochSecond) / 3600.0
    val match = solar.minByOrNull { kotlin.math.abs(it.validFrom.epochSecond - rate.validFrom.epochSecond) }
    val ghi = match?.takeIf { kotlin.math.abs(it.validFrom.epochSecond - rate.validFrom.epochSecond) <= 900 }?.ghiWm2 ?: 0.0
    val rawKw = settings.effectiveKwp * (ghi.coerceAtLeast(0.0) / 1000.0)
    val adjustedKw = rawKw * (1.0 - settings.systemLossPercent.coerceIn(0.0, 100.0) / 100.0)
    val pvKw = if (settings.inverterMaxKw > 0) minOf(adjustedKw, settings.inverterMaxKw) else adjustedKw
    val pvKwh = if (settings.pvInstalled) pvKw * hours else 0.0
    val loadKwh = settings.loadKw.coerceAtLeast(0.0) * hours
    val avoided = minOf(pvKwh, loadKwh)
    val grid = (loadKwh - pvKwh).coerceAtLeast(0.0)
    val saving = avoided * rate.pencePerKwh
    val net = if (loadKwh > 0) grid * rate.pencePerKwh / loadKwh else rate.pencePerKwh
    DerivedPeriod(rate.validFrom, rate.validTo, rate.pencePerKwh, ghi, pvKwh, loadKwh, avoided, grid, net, saving)
}
