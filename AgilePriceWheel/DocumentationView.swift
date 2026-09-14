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

                Section("Six page buttons") {
                    Text("A fixed six-button navigation bar is shown at the bottom of every page. Tap Prices, Solar, PV, Net, Settings or Guide to jump directly to that page.")
                    Text("The selected page button is highlighted in orange.")
                    Text("Horizontal swipe navigation is intentionally disabled so touching or dragging a wheel sector cannot accidentally change the main page.")
                    Text("The older Back/Next controls, page dots, page-number indicator and swipe-navigation footer instructions have been removed.")
                }

                Section("Navigation symbols") {
                    Text("Prices uses a lightning bolt, Solar uses a sun, PV uses a sun/bolt symbol, Net uses a pound symbol, Settings uses sliders and Guide uses a book.")
                }

                Section("Now button") {
                    Text("Octopus Agile Prices, Solar Forecast, PV Forecast and Net Electricity Price each have a Now button.")
                    Text("Tapping Now returns the shared selected date to today, loads today's source data if required and selects the half-hour containing the current time using validFrom ≤ now < validTo.")
                }

                Section("Octopus Agile Prices") {
                    Text("The first wheel shows the published Octopus Agile import price for each settlement period. Touch or drag around the wheel to select a half-hour.")
                    Text("Lowest, highest, average and selected prices are shown. Negative prices are blue; positive prices use a day-relative green-to-red scale.")
                    Text("UK daylight-saving days containing 46 or 50 half-hours are supported.")
                }

                Section("Solar Forecast") {
                    Text("The Solar Forecast wheel shows forecast global horizontal irradiance (GHI / shortwave radiation) in W/m².")
                    Text("Open-Meteo 15-minute shortwave-radiation samples are combined into half-hour values.")
                    Text("Solar Forecast remains available when Solar PV panels installed is turned off.")
                }

                Section("Solar site") {
                    Text("Set or change the forecast site from App Settings.")
                    Text("Use Current Location requests iOS When-In-Use permission only when tapped. The app does not continuously track location.")
                    Text("Place/postcode search and manual coordinates remain available if location permission is denied.")
                }

                Section("PV Forecast") {
                    Text("PV Forecast estimates half-hour PV electrical output from the solar forecast plus configured array capacity, losses and inverter limit.")
                    Text("Estimated power = array kWp × (GHI ÷ 1000) × (1 − system-loss percentage), clipped to the configured inverter maximum when one is set. Energy = power × actual period duration.")
                    Text("Rated kWp takes priority; otherwise panel count × panel watts ÷ 1000 can provide array capacity.")
                    Text("If Solar PV panels installed is off, PV Forecast is greyed and disabled while saved settings are retained.")
                }

                Section("PV-array units") {
                    Text("PV numeric fields keep their engineering units visible beside the editable value.")
                    Text("Rated peak power: kWp. Panel rating: W. Panel tilt: °. Azimuth: °. Inverter maximum AC output: kW. Estimated system losses: %.")
                    Text("Number of panels is dimensionless. Unit labels are display-only and are not stored as part of the numeric value.")
                }

                Section("Net Electricity Price") {
                    Text("The Net Electricity Price wheel estimates the effective p/kWh cost of running the configured load after forecast PV reduces expected grid import.")
                    Text("Load energy = load kW × period hours; grid import = max(load energy − forecast PV, 0); slot cost = grid import × Agile price; net price = slot cost ÷ complete load energy.")
                    Text("The default optimiser load is 3.0 kW. Household background demand and export income are not yet separately included.")
                }

                Section("App Settings") {
                    Text("App Settings centralises Agile tariff/day controls, source refresh, solar site, PV availability, Solar PV array settings and optimiser load.")
                    Text("When Solar PV panels installed is off, PV-array and optimiser controls are disabled, PV Forecast and Net Electricity Price are greyed, Solar Forecast stays active, and saved values are retained.")
                    Text("Azimuth convention: 0° North, 90° East, 180° South, 270° West.")
                }

                Section("Server, cache and offline use") {
                    Text("Agile and solar source data are cached locally after successful downloads.")
                    Text("PV Forecast and Net Electricity Price are local derived calculations and can be recalculated from cached source data when the required settings are present.")
                    Text("This User Guide is bundled into the app and remains available offline.")
                }

                Section("Privacy") {
                    Text("The public tariff/rate features do not require Octopus login credentials, API key, MPAN, meter serial number or payment information.")
                    Text("Location permission is requested only when Use Current Location is tapped. Selected coordinates are stored locally and sent to Open-Meteo when needed for forecast/geocoding requests.")
                }

                Section("Technical architecture") {
                    Text("SwipeDashboardView coordinates the six pages, direct bottom-button navigation, Now behaviour and PV-disabled presentation state. Its historical name remains even though swipe page-changing is no longer used.")
                    Text("The user-facing PV Forecast page is implemented by GenerationEstimateView.")
                    Text("The app is native Swift/SwiftUI with no third-party package dependencies.")
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
