import SwiftUI

/// User-facing documentation shipped with the app.
/// Keep this in sync with README.md and USER_GUIDE.md whenever behaviour changes.
struct DocumentationView: View {
    @Environment(\.dismiss) private var dismiss

    var showsDoneButton: Bool = true
    var navigationTitle: String = "Guide & Documentation"

    var body: some View {
        NavigationStack {
            List {
                Section("What the app does") {
                    Text("Agile Price Wheel combines Octopus Agile half-hour prices, solar irradiance forecasts, a PV Forecast and a solar-adjusted Net Electricity Price for a configurable load.")
                    Text("The first dashboard page is titled Octopus Agile Prices. The project and repository remain named AgilePriceWheel.")
                }

                Section("Six swipe pages") {
                    Text("The page order is: 1. Octopus Agile Prices, 2. Solar Forecast, 3. PV Forecast, 4. Net Electricity Price, 5. App Settings, 6. User Guide.")
                    Text("Swipe left to move forward. Swiping left from User Guide wraps back to Octopus Agile Prices. Swipe right to move back; the first page does not wrap backwards.")
                    Text("Six page dots show your current page.")
                }

                Section("Now button") {
                    Text("Octopus Agile Prices, Solar Forecast, PV Forecast and Net Electricity Price each have a Now button.")
                    Text("Tapping Now returns the shared selected date to today, loads today's source data if required and selects the half-hour containing the current time using validFrom ≤ now < validTo.")
                    Text("PV Forecast and Net Electricity Price are refreshed so their selected metrics also move to the current half-hour.")
                }

                Section("Octopus Agile Prices") {
                    Text("The first wheel shows the published Octopus Agile import price for each settlement period. Touch or drag around the wheel to select a half-hour.")
                    Text("Lowest, highest, average and selected prices are shown. Negative prices are blue; positive prices use a day-relative green-to-red scale.")
                    Text("UK daylight-saving days containing 46 or 50 half-hours are supported.")
                }

                Section("Solar Forecast") {
                    Text("The second wheel shows forecast global horizontal irradiance (GHI / shortwave solar radiation) in W/m² for the same selected day.")
                    Text("Open-Meteo 15-minute shortwave-radiation samples are combined into half-hour values.")
                    Text("Solar Forecast stays available even when Solar PV panels installed is turned off.")
                }

                Section("Solar site") {
                    Text("Set or change the forecast site from App Settings.")
                    Text("Use Current Location requests iOS When-In-Use location permission only when tapped and uses the device position as the solar forecast site. The app does not continuously track location.")
                    Text("You can alternatively search by place/postcode using Open-Meteo geocoding or enter latitude and longitude manually. Those methods remain available if location permission is denied.")
                }

                Section("PV Forecast") {
                    Text("The page previously named PV Generation is now named PV Forecast.")
                    Text("It estimates PV electrical output for each half-hour from the solar forecast plus the configured array capacity, losses and inverter limit.")
                    Text("The page shows estimated day total, peak output/time, selected half-hour energy/power and the effective array capacity used.")
                    Text("If Solar PV panels installed is off, PV Forecast is greyed and disabled while stored PV settings are retained.")
                }

                Section("PV Forecast calculation") {
                    Text("Estimated power = array kWp × (GHI ÷ 1000) × (1 − system-loss percentage). If an inverter maximum is configured, estimated power is clipped to that value. Energy = estimated power × actual period duration.")
                    Text("Rated kWp takes priority. If it is blank, panel count × panel watts ÷ 1000 is used when available.")
                    Text("Tilt and azimuth are stored but are not yet applied because the current weather input is horizontal GHI, not plane-of-array irradiance.")
                }

                Section("PV-array units") {
                    Text("Solar PV array fields keep their engineering units visible beside the editable numeric value. The suffix does not disappear after a value is entered.")
                    Text("Rated peak power: kWp. Panel rating: W. Panel tilt: °. Azimuth: °. Inverter maximum AC output: kW. Estimated system losses: %.")
                    Text("Number of panels is dimensionless. Enter only the numeric value; the unit label is display-only and is not stored as part of the number.")
                }

                Section("PV availability") {
                    Text("App Settings includes Solar PV panels installed. Turn it off for a property without PV.")
                    Text("When off, PV-array controls, optimiser controls, PV Forecast and Net Electricity Price are greyed and disabled. Solar Forecast remains active.")
                    Text("Turning PV off does not erase saved PV details or optimiser load. Turning it back on restores them.")
                }

                Section("Net Electricity Price") {
                    Text("The fourth wheel estimates the effective p/kWh cost of running the configured load after forecast PV reduces expected grid import.")
                    Text("For each period: load energy = load kW × period hours; grid import = max(load energy − forecast PV, 0); slot cost = grid import × Agile price; net price = slot cost ÷ complete load energy.")
                    Text("The default optimiser load is 3.0 kW, matching the established nightly email model.")
                    Text("The model does not yet subtract ordinary household background demand first and does not credit export income.")
                }

                Section("Net-price colours") {
                    Text("Fixed bands are used: below 0 dark green; 0–5 green; 5–10 lime; 10–20 light green; 20–30 yellow; 30–40 orange; 40–50 red; 50+ dark red.")
                }

                Section("App Settings") {
                    Text("App Settings centralises Agile tariff/day controls, source refresh, solar site, PV availability, Solar PV array settings and optimiser load.")
                    Text("Azimuth convention: 0° North, 90° East, 180° South, 270° West.")
                }

                Section("Server, cache and offline use") {
                    Text("Agile and solar source data are cached locally after successful downloads.")
                    Text("PV Forecast and Net Electricity Price are local derived calculations and can be recalculated from cached source data when the required settings are present.")
                    Text("This User Guide is bundled into the app and remains available offline.")
                }

                Section("Privacy") {
                    Text("The public tariff/rate features do not require Octopus login credentials, API key, MPAN, meter serial number or payment information.")
                    Text("Location permission is requested only when Use Current Location is tapped. The selected site coordinates are stored locally and sent to Open-Meteo when forecast/geocoding requests require them.")
                    Text("PV settings, optimiser load and derived calculations remain local.")
                }

                Section("Technical architecture") {
                    Text("AgileViewModel coordinates OctopusAPI and AgileCacheStore. SolarForecastModel coordinates SolarForecastAPI and SolarForecastCache. AppSettingsStore persists PV settings and optimiser settings.")
                    Text("The user-facing PV Forecast page is implemented by GenerationEstimateView. The internal Swift type keeps its existing name even though the page title changed.")
                    Text("SwipeDashboardView coordinates the six pages, Now behaviour and PV-disabled presentation state.")
                    Text("The app is native Swift/SwiftUI with no third-party package dependencies.")
                }

                Section("Documentation maintenance") {
                    Text("README.md is the technical/developer reference, USER_GUIDE.md is the complete operating guide and this view is the in-app offline guide. Functional changes must keep them synchronized with the implementation.")
                }

                Section("Accuracy and disclaimer") {
                    Text("Solar irradiance, PV Forecast and Net Electricity Price are forecasts/derived planning estimates and can differ from actual generation, energy flows and bills.")
                    Text("Agile Price Wheel is independent and is not an official Octopus Energy or Open-Meteo application.")
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
