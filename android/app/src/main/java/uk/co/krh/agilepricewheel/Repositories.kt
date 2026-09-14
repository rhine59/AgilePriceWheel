package uk.co.krh.agilepricewheel

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId

object AgileRepository {
    suspend fun rates(product: String, tariff: String, date: LocalDate): List<AgileRate> = withContext(Dispatchers.IO) {
        val zone = ZoneId.of("Europe/London")
        val from = date.atStartOfDay(zone).toInstant()
        val to = date.plusDays(1).atStartOfDay(zone).toInstant()
        val url = "https://api.octopus.energy/v1/products/$product/electricity-tariffs/$tariff/standard-unit-rates/?period_from=$from&period_to=$to&page_size=100"
        val root = getJson(url)
        val results = root.getJSONArray("results")
        buildList {
            for (i in 0 until results.length()) {
                val o = results.getJSONObject(i)
                add(AgileRate(Instant.parse(o.getString("valid_from")), Instant.parse(o.getString("valid_to")), o.getDouble("value_inc_vat")))
            }
        }.sortedBy { it.validFrom }
    }
}

object SolarRepository {
    suspend fun forecast(latitude: Double, longitude: Double, date: LocalDate): List<SolarPeriod> = withContext(Dispatchers.IO) {
        val url = "https://api.open-meteo.com/v1/forecast?latitude=$latitude&longitude=$longitude&minutely_15=shortwave_radiation&timezone=Europe%2FLondon&start_date=$date&end_date=$date"
        val root = getJson(url)
        val block = root.getJSONObject("minutely_15")
        val times = block.getJSONArray("time")
        val values = block.getJSONArray("shortwave_radiation")
        val zone = ZoneId.of("Europe/London")
        val samples = (0 until times.length()).map { i ->
            java.time.LocalDateTime.parse(times.getString(i)).atZone(zone).toInstant() to values.optDouble(i, 0.0)
        }
        samples.chunked(2).mapNotNull { pair ->
            if (pair.isEmpty()) null else {
                val start = pair.first().first
                val end = if (pair.size > 1) pair.last().first.plusSeconds(900) else start.plusSeconds(1800)
                SolarPeriod(start, end, pair.map { it.second }.average())
            }
        }
    }
}

private fun getJson(url: String): JSONObject {
    val connection = URL(url).openConnection() as HttpURLConnection
    connection.connectTimeout = 15000
    connection.readTimeout = 20000
    connection.setRequestProperty("Accept", "application/json")
    connection.setRequestProperty("User-Agent", "AgilePriceWheel-Android/1.0")
    return try {
        val code = connection.responseCode
        if (code !in 200..299) error("HTTP $code")
        JSONObject(connection.inputStream.bufferedReader().use { it.readText() })
    } finally { connection.disconnect() }
}
