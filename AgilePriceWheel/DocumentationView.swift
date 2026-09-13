import SwiftUI

/// User-facing documentation shipped with the app.
///
/// IMPORTANT: Keep this guide in sync with README.md and USER_GUIDE.md
/// whenever application behaviour, setup, data sources, calculations,
/// caching, controls, privacy or dependencies change.
struct DocumentationView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Overview") {
                    Text("Agile Price Wheel combines Octopus Energy Agile half-hour electricity prices, a same-day solar irradiance forecast, a locally calculated PV generation estimate and persistent site/PV settings.")
                    Text("The app is organised as four horizontally swiped pages. The information button on the main pages opens this complete guide, which is bundled inside the app and remains available offline.")
                }

                Section("Page order and navigation") {
                    Text("Page 1: Agile Prices. Swipe left to Page 2: Solar Forecast. Swipe left again to Page 3: PV Generation. Swipe left once more to Page 4: App Settings.")
                    Text("Swipe right to move back in the opposite direction: Settings → Generation → Solar → Prices. The four page dots indicate your current position.")
                    Text("The gear button on the Solar Forecast and PV Generation pages jumps directly to App Settings. Settings is deliberately the final swipe page so the three day-information pages are together first.")
                }

                Section("Page 1 — Agile Prices") {
                    Text("The Agile price wheel shows one coloured sector for every published half-hour settlement period in the selected UK day. Touch or drag around the wheel to select a period.")
                    Text("The centre of the wheel shows the selected price and time. Summary tiles show the lowest price and time, highest price and time, daily average and chosen half-hour.")
                    Text("The Prices, Chart and Details controls provide three views of the same tariff data. Chart displays each half-hour as a horizontal bar. Details shows the selected period and current tariff metadata.")
                }

                Section("Agile price colours") {
                    Text("Negative prices are blue. Positive prices are coloured relative to that selected day: lower prices are green, moving through yellow/orange to red for the most expensive periods.")
                    Text("The colour scale is relative, not a universal tariff threshold. A green sector means cheaper than the other positive periods in the displayed day.")
                }

                Section("Agile data source") {
                    Text("SERVER DATA means the displayed prices were obtained successfully from Octopus. LOCAL CACHE means a previously saved copy is being shown. The label includes the relevant update or save time.")
                    Text("On launch and on date changes, the app restores cached prices first when available and then attempts to refresh from Octopus. If the server is unavailable, cached prices remain usable.")
                }

                Section("Page 2 — Solar Forecast") {
                    Text("The Solar Forecast page follows the same selected calendar day as Agile Prices. Its wheel shows forecast global horizontal irradiance (GHI), also called shortwave solar radiation, in watts per square metre (W/m²).")
                    Text("The app obtains 15-minute shortwave-radiation values from Open-Meteo and combines consecutive values into half-hour periods. Touch or drag around the solar wheel to inspect a half-hour.")
                    Text("Summary tiles show peak irradiance and time, daylight average, the selected half-hour and the latitude/longitude used for the forecast.")
                }

                Section("Solar site setup") {
                    Text("A site must be configured before solar data can be fetched. In App Settings choose Set solar site or Change solar site.")
                    Text("You can search by place name or postcode using Open-Meteo geocoding, or enter latitude and longitude manually. Latitude must be between −90 and 90; longitude between −180 and 180.")
                    Text("The selected site name and coordinates are stored locally. The current app does not request live iPhone GPS access.")
                }

                Section("Solar caching and refresh") {
                    Text("Each successfully downloaded site/day solar forecast is cached on the device. Cache entries include the site coordinates and date, so changing site does not overwrite another site's saved forecast.")
                    Text("App Settings contains Refresh solar forecast. If refresh fails and a cached copy exists, the cached forecast remains displayed and can still feed the PV Generation page.")
                }

                Section("Page 3 — PV Generation") {
                    Text("PV Generation is a locally derived estimate for the same day. Each sector represents estimated electrical energy generated during that half-hour in kWh rather than irradiance in W/m².")
                    Text("Touch or drag around the wheel to inspect a period. The page shows estimated total generation for the day, peak estimated output in kW and its time, selected half-hour energy and average power, and the array capacity used.")
                    Text("The generation page has no separate web API. It recalculates automatically from the currently loaded solar forecast and the PV settings stored on the device.")
                }

                Section("Generation calculation") {
                    Text("For each period: irradiance factor = max(GHI, 0) ÷ 1000. Raw PV power = effective array kWp × irradiance factor. Loss-adjusted power = raw PV power × (1 − system loss percentage).")
                    Text("If a positive inverter maximum is configured, estimated power is limited to that inverter value. Estimated energy = estimated power × the actual period duration in hours.")
                    Text("An explicitly entered rated kWp value takes priority. If it is blank, panel count × panel wattage ÷ 1000 is used when both values are available.")
                }

                Section("Generation-model limitations") {
                    Text("The current weather input is horizontal irradiance (GHI), not plane-of-array irradiance. Tilt and azimuth are stored for future use but are not yet applied to the generation calculation.")
                    Text("The current estimate also does not explicitly model shading, panel temperature, snow/soiling, detailed inverter efficiency curves, degradation, mismatch/string losses, horizon obstruction or albedo.")
                    Text("Treat the generation values as first-order forecast estimates, not guaranteed electrical production.")
                }

                Section("Page 4 — App Settings") {
                    Text("App Settings is the final swipe page and centralises configuration for the whole app. It contains the selected Agile tariff, selected day, Agile refresh, solar site, solar refresh, PV-array details and current data-source status.")
                    Text("Changes to the selected date affect the Agile, Solar and Generation pages together. Changes to PV settings immediately affect the locally calculated Generation page.")
                }

                Section("PV array settings") {
                    Text("Stored fields include array name, rated peak power in kWp, panel count, panel rating in watts, tilt in degrees, azimuth in degrees, inverter maximum AC output in kW, estimated system losses in percent and notes.")
                    Text("Azimuth convention is 0° North, 90° East, 180° South and 270° West. If panel count and panel rating are entered, the app shows the implied array capacity in kWp.")
                    Text("PV settings are stored locally in UserDefaults. They are not sent to Octopus or Open-Meteo by the current implementation.")
                }

                Section("Tariff selection") {
                    Text("The app dynamically discovers currently available Octopus Energy Agile import tariffs instead of relying on one hard-coded product code. The selected tariff is remembered on the device.")
                    Text("If no saved choice can be restored, the app prefers Yorkshire when available and otherwise uses the first discovered Agile tariff.")
                }

                Section("Daylight-saving time") {
                    Text("All date logic uses the Europe/London calendar. Normal days contain 48 half-hours, the spring clock-change day can contain 46, and the autumn clock-change day can contain 50.")
                    Text("The price and solar views use the actual returned periods, and generation uses each period's real start/end duration rather than assuming every slot or day is fixed.")
                }

                Section("Offline operation") {
                    Text("Agile prices and solar forecasts that have already been downloaded can be restored from local cache when there is no network connection.")
                    Text("PV Generation can also work offline when the necessary solar forecast is cached because generation is calculated locally from cached irradiance plus local PV settings.")
                    Text("Offline mode cannot obtain a new tariff catalogue, new prices, a new geocoding result or a solar forecast for a site/day that has never previously been downloaded.")
                }

                Section("Refresh controls") {
                    Text("App Settings provides Refresh Agile prices and Refresh solar forecast. These actions attempt the online services while preserving usable cached data if a refresh fails.")
                    Text("PV Generation does not need a separate refresh button. It updates automatically when the solar forecast, selected day or PV settings change.")
                }

                Section("How the app works") {
                    Text("AgilePriceWheelApp starts SwipeDashboardView. AgileViewModel manages Agile tariff/date/rate state, OctopusAPI performs Octopus requests and AgileCacheStore persists downloaded tariff/rate data.")
                    Text("SolarForecastModel manages site and irradiance state. SolarForecastAPI performs Open-Meteo forecast/geocoding requests and SolarForecastCache persists site/day forecasts.")
                    Text("AppSettingsStore persists PV configuration. GenerationEstimateView combines SolarHalfHour values with those settings to create GenerationHalfHour estimates locally. SwipeDashboardView coordinates the four pages and shared selected day.")
                }

                Section("Network services") {
                    Text("Octopus Energy public REST endpoints supply Agile product/tariff metadata and standard unit rates. No Octopus account number, API key, MPAN, meter serial number or login is required for the endpoints used by this app.")
                    Text("Open-Meteo supplies solar shortwave-radiation forecasts and place/postcode geocoding. The configured latitude and longitude are sent to Open-Meteo when requesting a forecast.")
                }

                Section("Local storage and privacy") {
                    Text("UserDefaults stores lightweight preferences such as selected tariff, selected solar site and PV-array configuration. Application Support JSON files store Agile tariff/rate caches and solar forecast caches.")
                    Text("The app does not currently request payment information, meter identifiers or live GPS location. Derived PV generation is calculated on-device and is not uploaded by the current implementation.")
                }

                Section("Dependencies") {
                    Text("The app is native Swift/SwiftUI and currently uses no third-party package dependencies. It uses Apple SwiftUI, Foundation and Combine, with URLSession for networking and Codable/JSONEncoder/JSONDecoder for JSON data.")
                }

                Section("Troubleshooting") {
                    Text("If Agile prices are missing, confirm a tariff is selected, the date has published rates, and try Refresh Agile prices. If LOCAL CACHE is shown, the server refresh failed but saved data is still available.")
                    Text("If Solar Forecast is empty, confirm a site is set and try Refresh solar forecast. If PV Generation is empty, confirm both a solar forecast and an effective array capacity are available.")
                    Text("If generation looks unrealistic, check rated kWp or panel count/wattage, inverter maximum and system-loss percentage, and remember that tilt/azimuth are not yet applied.")
                }

                Section("Accuracy and disclaimer") {
                    Text("Electricity prices include VAT unless explicitly labelled otherwise. Solar irradiance is a weather-model forecast. PV Generation is a derived estimate and can differ materially from actual site output.")
                    Text("Agile Price Wheel is an independent application and is not an official Octopus Energy or Open-Meteo application. Verify electricity prices against your actual tariff before relying on them for billing or financial decisions.")
                }

                Section("Documentation maintenance") {
                    Text("The repository contains README.md for technical/developer documentation and USER_GUIDE.md for the complete operating guide. This in-app DocumentationView.swift is the offline user-facing copy. Future functional changes must review and update all relevant documentation in the same change.")
                }
            }
            .navigationTitle("Guide & Documentation")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
