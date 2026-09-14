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
                Section("Index") {
                    Text("1. Conditional page buttons")
                    Text("2. Now button")
                    Text("3. Octopus Agile Prices")
                    Text("4. Solar Forecast and solar site")
                    Text("5. PV Forecast")
                    Text("6. Net Electricity Price")
                    Text("7. Cost Savings")
                    Text("8. App Settings and PV-array units")
                    Text("9. Cache, privacy and technical architecture")
                }

                Section("What the app does") {
                    Text("Agile Price Wheel combines Octopus Agile half-hour prices, solar irradiance forecasts, a PV Forecast, a solar-adjusted Net Electricity Price and forecast PV Cost Savings.")
                    Text("The first dashboard page is titled Octopus Agile Prices. The project and repository remain named AgilePriceWheel.")
                }

                Section("Conditional page buttons") {
                    Text("When Solar PV panels installed is on, the bottom navigation shows Prices, Solar, PV, Net, Save, Settings and Guide.")
                    Text("When Solar PV panels installed is off, PV, Net and Save are hidden, leaving Prices, Solar, Settings and Guide. Turning PV back on restores the three hidden pages immediately and keeps the saved PV-array and optimiser values.")
                    Text("Save opens Cost Savings. The selected page button is highlighted in orange.")
                    Text("Horizontal swipe navigation is intentionally disabled so touching or dragging a wheel sector cannot accidentally change the main page.")
                }

                Section("Navigation symbols") {
                    Text("Prices uses a lightning bolt, Solar a sun, PV a sun/bolt, Net a pound symbol, Save a banknote, Settings sliders and Guide a book.")
                }

                Section("Now button") {
                    Text("Octopus Agile Prices and Solar Forecast always have a Now button. PV Forecast, Net Electricity Price and Cost Savings also have Now when those pages are visible.")
                    Text("Tapping Now returns the shared selected date to today, loads today's source data if required and selects the half-hour containing the current time using validFrom ≤ now < validTo.")
                    Text("Now is part of the page layout rather than a floating overlay, so SwiftUI reserves space for it and it should not cover descriptions, wheels or metric cards on supported iPhone sizes.")
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
                    Text("After obtaining the coordinates, the app reverse-geocodes them to a familiar locality or town name and saves that as the site label. If a common name cannot be resolved, Current location is used as a fallback.")
                    Text("The saved site name is editable. Changing the label does not alter the saved latitude or longitude used for the forecast.")
                    Text("Place/postcode search and manual coordinates remain available if location permission is denied.")
                }

                Section("PV Forecast") {
                    Text("PV Forecast estimates half-hour PV electrical output from the solar forecast plus configured array capacity, losses and inverter limit.")
                    Text("Estimated power = array kWp × (GHI ÷ 1000) × (1 − system-loss percentage), clipped to the configured inverter maximum when one is set. Energy = power × actual period duration.")
                    Text("Rated kWp takes priority; otherwise panel count × panel watts ÷ 1000 can provide array capacity.")
                    Text("If Solar PV panels installed is off, PV Forecast and its bottom navigation button are hidden. They return when PV is switched on again.")
                }

                Section("Net Electricity Price") {
                    Text("The Net Electricity Price wheel estimates the effective p/kWh cost of running the configured load after forecast PV reduces expected grid import.")
                    Text("Load energy = load kW × period hours; grid import = max(load energy − forecast PV, 0); slot cost = grid import × Agile price; net price = slot cost ÷ complete load energy.")
                    Text("The selected wheel sector also shows PV saving in pence. The Selected half-hour breakdown repeats that saving and the PV energy used against the load.")
                    Text("This page is hidden when Solar PV panels installed is off and returns when PV is enabled again.")
                }

                Section("Cost Savings") {
                    Text("Cost Savings is a separate half-hour wheel showing the import-cost saving created by forecast PV generation.")
                    Text("Avoided grid import = min(forecast PV energy, configured load energy). PV cost saving = avoided grid import × Agile price.")
                    Text("The page shows each half-hour saving, forecast day saving, best half-hour, total avoided grid import and a selected-period breakdown.")
                    Text("Surplus PV export income is not included. If the Agile price is negative, the saving can be negative because importing would have been financially beneficial. Negative saving sectors are red and positive sectors are green.")
                    Text("This page is hidden when Solar PV panels installed is off and returns when PV is enabled again.")
                }

                Section("PV-array units") {
                    Text("PV numeric fields keep their engineering units visible beside the editable value.")
                    Text("Rated peak power: kWp. Panel rating: W. Panel tilt: °. Azimuth: °. Inverter maximum AC output: kW. Estimated system losses: %.")
                    Text("Number of panels is dimensionless. Unit labels are display-only and are not stored as part of the numeric value.")
                }

                Section("App Settings") {
                    Text("App Settings centralises Agile tariff/day controls, source refresh, solar site, PV availability, Solar PV array settings and optimiser load.")
                    Text("When Solar PV panels installed is off, PV, Net and Save disappear from bottom navigation; PV-array and optimiser controls are disabled; Solar Forecast stays active; saved values are retained. Turning PV back on restores the three pages immediately.")
                    Text("Azimuth convention: 0° North, 90° East, 180° South, 270° West.")
                }

                Section("Server, cache and offline use") {
                    Text("Agile and solar source data are cached locally after successful downloads.")
                    Text("PV Forecast, Net Electricity Price and Cost Savings are local derived calculations and can be recalculated from cached source data when the required settings are present.")
                    Text("This indexed User Guide is bundled into the app and remains available offline.")
                }

                Section("Privacy") {
                    Text("The public tariff/rate features do not require Octopus login credentials, API key, MPAN, meter serial number or payment information.")
                    Text("Location permission is requested only when Use Current Location is tapped. The selected coordinates are stored locally, used with Apple's reverse-geocoding service to obtain a readable site name, and sent to Open-Meteo when needed for solar forecast requests.")
                }

                Section("Technical architecture") {
                    Text("SwipeDashboardView coordinates seven defined pages, conditional bottom-button navigation, Now behaviour and PV-dependent visibility. Its historical name remains even though swipe page-changing is no longer used.")
                    Text("GenerationEstimateView implements PV Forecast. CostSavingsView implements Cost Savings. NetEffectivePriceView also calculates and displays the selected sector's PV saving.")
                    Text("The app is native Swift/SwiftUI with no third-party package dependencies.")
                }

                Section("Accuracy and disclaimer") {
                    Text("Solar irradiance, PV Forecast, Net Electricity Price and Cost Savings are forecasts/derived planning estimates and can differ from actual generation, energy flows and bills.")
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
