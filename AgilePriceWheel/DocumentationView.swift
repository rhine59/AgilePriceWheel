import SwiftUI

/// User-facing documentation shipped with the app.
///
/// IMPORTANT: Keep this guide in sync with README.md and USER_GUIDE.md
/// whenever application behaviour, setup, data sources, calculations,
/// caching, controls, privacy or dependencies change.
struct DocumentationView: View {
    @Environment(\.dismiss) private var dismiss

    var showsDoneButton: Bool = true
    var navigationTitle: String = "Guide & Documentation"

    var body: some View {
        NavigationStack {
            List {
                Section("What Agile Price Wheel does") {
                    Text("Agile Price Wheel combines Octopus Agile half-hour electricity prices, solar irradiance forecasts, PV-generation estimates and a solar-adjusted Net Electricity Price for a configurable load.")
                    Text("Agile and solar information come from public online APIs. PV Generation and Net Electricity Price are calculated locally on the device from those source datasets and your saved settings.")
                }

                Section("Six swipe pages") {
                    Text("The page order is: 1. Agile Prices, 2. Solar Forecast, 3. PV Generation, 4. Net Electricity Price, 5. App Settings, 6. User Guide.")
                    Text("Swipe left to move forward. The User Guide is the final page; swiping left once more from it wraps directly back to Agile Prices, creating a continuous loop.")
                    Text("Swipe right to move back one page. From the User Guide, a right swipe returns to App Settings. Six page dots show your position.")
                    Text("Gear buttons on Solar Forecast, PV Generation and Net Electricity Price jump directly to App Settings.")
                }

                Section("User Guide page") {
                    Text("The complete in-app guide is itself the sixth swipe page, so help is always available by continuing to swipe left through the app.")
                    Text("The same guide can still be opened as a sheet from the information buttons elsewhere in the app. When opened as a sheet it has a Done button; on the swipe page it does not.")
                }

                Section("Agile Prices") {
                    Text("The first wheel shows the published Octopus Agile import price for each half-hour. Touch or drag around the wheel to select a period.")
                    Text("Lowest, highest, average and selected prices are shown. Negative prices are blue; positive prices use a day-relative green-to-red scale.")
                    Text("Prices, Chart and Details provide the wheel, chronological bars and selected tariff/period information.")
                }

                Section("Solar Forecast") {
                    Text("The second wheel shows forecast global horizontal irradiance (GHI / shortwave solar radiation) in W/m² for the same selected day.")
                    Text("Solar data comes from Open-Meteo 15-minute shortwave-radiation forecasts. Consecutive samples are combined into half-hour values.")
                    Text("The page shows selected irradiance, peak/time, daylight average, site coordinates and server/cache status.")
                }

                Section("Solar site") {
                    Text("Set the forecast site in App Settings. Search by place/postcode using Open-Meteo geocoding or enter latitude and longitude manually.")
                    Text("The app currently does not request live iPhone GPS permission.")
                }

                Section("PV Generation") {
                    Text("The third wheel estimates electrical energy generated during each half-hour in kWh. It uses the loaded solar forecast plus your configured PV-array capacity, losses and inverter limit.")
                    Text("The page shows estimated day total, peak output/time, selected half-hour energy/power and the effective array capacity used.")
                }

                Section("PV generation calculation") {
                    Text("Estimated power = array kWp × (GHI ÷ 1000) × (1 − system-loss percentage). If an inverter maximum is configured, estimated power is clipped to that value. Energy = estimated power × actual period duration.")
                    Text("Rated kWp takes priority. If it is blank, panel count × panel watts / 1000 is used when available.")
                    Text("Tilt and azimuth are stored but are not yet applied because the current input is horizontal GHI, not plane-of-array irradiance.")
                }

                Section("Net Electricity Price") {
                    Text("Swipe left from PV Generation for the fourth wheel. It reproduces the optimiser logic used by the nightly Agile + solar email.")
                    Text("Each sector shows the effective p/kWh cost of running the configured controllable load after forecast PV has reduced the amount expected to be imported from the grid.")
                    Text("The page shows best, highest and average net prices plus a detailed breakdown for the selected half-hour: published Agile price, load energy, forecast PV, expected grid import, slot cost and net/adjusted p/kWh.")
                }

                Section("Net-price calculation") {
                    Text("For each period: load energy = configured load kW × period hours. Grid import = max(load energy − forecast PV energy, 0). Slot cost = grid import × Agile price. Net price = slot cost ÷ complete load energy.")
                    Text("Example: at 20p/kWh, a 3 kW load uses 1.5 kWh in 30 minutes. If forecast PV is 0.9 kWh, grid import is 0.6 kWh, slot cost is 12p and the effective price is 8p/kWh.")
                    Text("The optimiser load defaults to 3.0 kW to match the established nightly email model, and can be changed in App Settings.")
                }

                Section("Net-price assumptions") {
                    Text("All forecast PV is assumed available to the controllable load. Normal household background demand is not deducted first, and surplus-export income is not credited. If PV exceeds the load, expected grid import is floored at zero.")
                    Text("The result is an optimisation aid rather than an exact electricity-bill prediction.")
                }

                Section("Net-price colours") {
                    Text("The Net Electricity Price wheel uses fixed bands, matching the established email optimiser: below 0 dark green; 0–5 green; 5–10 lime; 10–20 light green; 20–30 yellow; 30–40 orange; 40–50 red; 50+ dark red.")
                    Text("Unlike the Agile wheel's day-relative positive colours, fixed net-price bands allow easier comparison between days.")
                }

                Section("App Settings") {
                    Text("The fifth swipe page centralises tariff, selected day, Agile refresh, solar site, solar refresh, PV-array details and optimiser load.")
                    Text("The Net price optimiser section contains Controllable load power (kW). New installs default to 3.0 kW and the screen shows the equivalent normal 30-minute load energy.")
                    Text("Swipe left from App Settings to reach the User Guide. Swipe right to return to Net Electricity Price.")
                }

                Section("PV-array fields") {
                    Text("PV settings include array name, rated kWp, panel count, panel watts, tilt, azimuth, inverter maximum AC output, estimated system losses and notes.")
                    Text("Azimuth convention: 0° North, 90° East, 180° South, 270° West.")
                }

                Section("Selected day and UK clock changes") {
                    Text("All data pages follow the same selected UK calendar day. Europe/London time is used.")
                    Text("Normal days contain 48 half-hours. Spring and autumn clock-change days can contain 46 or 50. Actual timestamps/durations are used instead of assuming 48 periods.")
                }

                Section("Server, cache and offline use") {
                    Text("Agile and solar pages show SERVER DATA, LOCAL CACHE or no-data status. Successfully downloaded tariff/rate and solar site/day data are stored locally.")
                    Text("PV Generation and Net Electricity Price are local calculations. If their required Agile and solar source data are cached, they can be recalculated offline.")
                    Text("The User Guide is bundled into the app and remains available offline. Offline mode cannot obtain source data that was never previously downloaded.")
                }

                Section("Refresh") {
                    Text("App Settings contains Refresh Agile prices and Refresh solar forecast. Successful refreshes update the corresponding cache; failed refreshes preserve an existing saved copy.")
                    Text("PV Generation and Net Electricity Price recalculate automatically when their source data or settings change.")
                }

                Section("Privacy and storage") {
                    Text("The app does not require Octopus login credentials, Octopus API key, MPAN, meter serial number, payment information or live GPS permission.")
                    Text("Selected tariff, site coordinates, PV settings and optimiser load are stored locally. Coordinates are sent to Open-Meteo when required for geocoding/forecast requests. PV settings and derived calculations remain local.")
                }

                Section("Technical architecture") {
                    Text("AgileViewModel coordinates OctopusAPI and AgileCacheStore. SolarForecastModel coordinates SolarForecastAPI and SolarForecastCache. AppSettingsStore persists PV and optimiser settings.")
                    Text("GenerationEstimateView derives PV energy from solar + PV settings. NetEffectivePriceView combines Agile rates, forecast PV generation and the configured load to create NetPriceHalfHour values. SwipeDashboardView coordinates all six pages, including the wrap from User Guide back to Agile Prices.")
                    Text("The app is native Swift/SwiftUI with no third-party package dependencies.")
                }

                Section("Accuracy and disclaimer") {
                    Text("Solar irradiance and PV generation are forecasts/estimates. Current PV modelling does not yet apply tilt/azimuth or detailed site effects such as shading and temperature.")
                    Text("Net Electricity Price does not include household background-load allocation or export revenue. Verify actual tariff data and energy decisions independently.")
                    Text("Agile Price Wheel is independent and is not an official Octopus Energy or Open-Meteo application.")
                }

                Section("Documentation maintenance") {
                    Text("README.md is the technical/developer reference, USER_GUIDE.md is the complete operating guide, and this view is the in-app offline guide. Future functional changes must keep all three synchronized with the implementation.")
                }
            }
            .navigationTitle(navigationTitle)
            .toolbar {
                if showsDoneButton {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                    }
                }
            }
        }
    }
}
