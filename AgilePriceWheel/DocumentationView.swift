import SwiftUI

/// User-facing documentation shipped with the app.
///
/// IMPORTANT: Keep this guide in sync with README.md whenever application
/// behaviour, setup, data sources, calculations, caching, controls or
/// dependencies change.
struct DocumentationView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("What Agile Price Wheel does") {
                    Text("Agile Price Wheel combines Octopus Energy Agile half-hour electricity prices, a same-day solar irradiance forecast, persistent site/PV settings and a derived half-hour PV generation estimate.")
                    Text("Agile tariff data comes from the public Octopus Energy API. Solar irradiance comes from Open-Meteo. The PV generation page is calculated locally from the downloaded solar forecast and the PV-array settings stored on the device.")
                }

                Section("Four swipe pages") {
                    Text("The main interface now has four horizontal pages: 1. Agile Prices, 2. Solar Forecast, 3. App Settings, 4. PV Generation.")
                    Text("Swipe left to move Prices → Solar → Settings → Generation. Swipe right to move back in the opposite direction.")
                }

                Section("Accessing this guide") {
                    Text("Tap the information button at the top-right of the electricity, solar, settings or generation screen to open this guide. It is bundled inside the app and remains available offline.")
                }

                Section("Agile price wheel") {
                    Text("Touch or drag around the electricity wheel to select a half-hour. The selected price and time are shown in the centre and in the Chosen slot tile.")
                    Text("Lowest and Highest tiles show both the value and its half-hour. Average price is calculated from all published periods for the selected day.")
                }

                Section("Price colours") {
                    Text("Negative Agile prices are blue. Positive prices use a scale relative to the selected day: cheaper periods are green, progressing through yellow/orange to red for more expensive periods.")
                    Text("A green period therefore means relatively cheap for that displayed day; it is not a fixed universal price threshold.")
                }

                Section("Solar Forecast page") {
                    Text("Swipe left from Agile Prices to Solar Forecast. The solar wheel uses the same selected calendar day and displays global horizontal irradiance (GHI / shortwave solar radiation) in W/m² for each half-hour.")
                    Text("Touch or drag around the solar wheel to inspect individual periods. The summary shows peak irradiance/time, daylight average, selected half-hour and the site coordinates used for the forecast.")
                }

                Section("Solar site") {
                    Text("The solar site is configured from App Settings. Search by place or postcode using Open-Meteo geocoding, or enter latitude and longitude manually.")
                    Text("The selected site name and coordinates are stored locally. The app currently does not request access to the iPhone's live GPS position.")
                }

                Section("App Settings page") {
                    Text("The third swipe page centralises the Agile tariff, selected day, Agile refresh, solar site, solar refresh, data-source status and PV-array configuration.")
                    Text("The gear button on the Solar Forecast and PV Generation screens also takes you to this settings page.")
                }

                Section("PV array settings") {
                    Text("PV settings include array name, rated peak power in kWp, panel count, panel watts, tilt, azimuth, inverter maximum AC output, estimated system losses and notes.")
                    Text("Azimuth convention is 0° North, 90° East, 180° South and 270° West. If rated kWp is not entered, the generation model can derive capacity from panel count × panel watts.")
                }

                Section("PV Generation page") {
                    Text("Swipe left once more from App Settings to open PV Generation. This page has another interactive half-hour wheel, but each sector represents estimated electrical energy generated during that period in kWh.")
                    Text("The page also shows the estimated whole-day total in kWh, peak estimated output in kW and its time, selected half-hour energy/output, and the array capacity used in the calculation.")
                }

                Section("Generation calculation") {
                    Text("The current model is intentionally simple and transparent. For each half-hour: estimated power = configured array kWp × (forecast GHI ÷ 1000) × (1 − configured loss percentage). If an inverter maximum is configured, the power is clipped to that value. Energy = estimated power × the actual period duration in hours.")
                    Text("An explicitly entered rated kWp value takes priority. If it is blank, panel count × panel rating is used when both are available. A blank system-loss field means no additional loss correction is applied.")
                }

                Section("Generation-model limitations") {
                    Text("The current generation estimate uses horizontal irradiance (GHI). Although tilt and azimuth are stored, they are not yet applied because the app does not yet convert GHI into plane-of-array irradiance.")
                    Text("The model also does not yet account explicitly for shading, panel temperature, snow/soiling, detailed inverter efficiency or other site-specific effects. The estimate should therefore be treated as a first-order forecast rather than a guaranteed generation value.")
                }

                Section("Selected day and DST") {
                    Text("All four pages follow the same selected UK calendar day. The app uses Europe/London time. Normal days contain 48 half-hours; spring and autumn clock-change days can contain 46 or 50.")
                    Text("Price, irradiance and generation displays use the actual period data/durations rather than assuming every day is exactly 24 hours.")
                }

                Section("Server and local data") {
                    Text("SERVER DATA means the displayed API data was obtained online. LOCAL CACHE means a previously saved copy is being used. Agile prices and solar forecasts have their own source indicators.")
                    Text("PV generation is derived locally from the currently available solar forecast and PV settings. If the solar forecast came from cache, the generation estimate is effectively based on that cached forecast.")
                }

                Section("Refresh") {
                    Text("App Settings contains Refresh Agile prices and Refresh solar forecast. Successful refreshes update the corresponding local cache. Failed refreshes leave an existing cached copy available.")
                    Text("The PV generation estimate recalculates automatically when its solar forecast or PV settings change; it does not require a separate server refresh.")
                }

                Section("Offline behaviour") {
                    Text("Previously cached Agile prices and solar forecasts can be displayed offline. PV generation can also be recalculated offline because it is derived locally from cached irradiance and locally stored PV settings.")
                    Text("A day or site that has never been downloaded cannot gain a new solar forecast while offline.")
                }

                Section("Solar forecast source") {
                    Text("Open-Meteo provides 15-minute shortwave-radiation values. The app combines consecutive values into half-hour solar periods so they align naturally with the Agile view.")
                    Text("The solar screen remains a weather/irradiance view in W/m². The generation screen is the separate derived electrical-energy estimate in kWh.")
                }

                Section("Octopus API") {
                    Text("The app uses public Octopus Energy product and standard-unit-rate endpoints. These do not require an Octopus account number, API key, MPAN, meter serial number or login credentials.")
                }

                Section("Privacy and local storage") {
                    Text("Tariff, site and PV-array settings are stored locally. Cached tariff metadata, prices and solar forecasts are stored in the app's Application Support area. PV generation estimates are calculated on-device from those values.")
                    Text("Configured latitude/longitude is sent to Open-Meteo when requesting a forecast. PV-array details are not sent to Octopus or Open-Meteo by the current implementation.")
                }

                Section("Technical architecture") {
                    Text("AgileViewModel coordinates OctopusAPI and AgileCacheStore. SolarForecastModel coordinates SolarForecastAPI and SolarForecastCache. AppSettingsStore persists PV configuration. GenerationEstimateView derives GenerationHalfHour values locally from SolarHalfHour values plus AppSettingsStore.")
                    Text("SwipeDashboardView coordinates the four pages and keeps them on the same selected day. The app is native Swift/SwiftUI with no third-party package dependencies.")
                }

                Section("Accuracy and disclaimer") {
                    Text("Electricity unit prices include VAT unless explicitly labelled otherwise. Solar irradiance and PV generation values are forecasts/estimates and may differ materially from measured conditions and actual generation.")
                    Text("Agile Price Wheel is independent and is not an official Octopus Energy or Open-Meteo application.")
                }

                Section("Documentation maintenance") {
                    Text("README.md in GitHub is the comprehensive developer/technical reference. This in-app guide is the user-facing companion. Every future functional change must review and update both README.md and DocumentationView.swift in the same change.")
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
