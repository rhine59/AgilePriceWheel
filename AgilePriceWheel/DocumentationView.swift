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
                Section("Agile heating — iOS") {
                    Text("Heating sessions link each ON and OFF, show duration and unit rates, and estimate kWh/cost using configured electrical load and effective prices after forecast solar. Negative totals show Estimated payment. These are not metered costs. Missing rates or an unconfirmed OFF leave cost unavailable. Older records have no reconstructed load history. A session crossing weeks appears in both with the same ID; do not add duplicates.")
                    Text("Missing or expired price data is shown as unavailable. Weekly heating log shows confirmed automation ON/OFF actions, prices and reasons by Monday–Sunday week. Use the arrows for older weeks and Reload or pull to refresh. Times show London GMT/BST; ON is red, OFF green. The controller keeps 366 days, starting when logging was installed. Manual Homely changes and compressor cycles are not included. Pending history warnings indicate saved actions awaiting a storage retry.")
                    Text("Agile heating shows separate Heating policy and Heating state lines: ON in red, OFF in green, and unavailable when data is missing or stale. Policy is price permission; state is Homely’s reported flag. Automatic activation is shown separately; use Automation to pause or resume the activated controller.")
                    Text("Set the controller address and key in App Settings under Agile heating connection, then Save connection. On Agile heating, use Test connection / reload controller policy. The key stays in Keychain; existing saved connections are retained.")
                    Text("The policy lists are Heating on and Heating off, from −20 to 20 p/kWh, including zero; negative values mean payment for grid import. Existing values outside the lists stay visible as Current. Homely keeps its existing temperature targets and schedules; this page does not set temperatures. Information is blue; errors are red.")
                    Text("Load policy, set the effective-price on/off points, and explicitly confirm saving. Copy this app's tariff, site and PV settings into the draft only when you choose. Off must be at least on; heating price permission starts at or below on and stops above off.")
                    Text("The controller calculates Agile plus forecast-PV effective prices independently of the phone and keeps running when the app closes. Status refreshes every 30 seconds while Heating is open. A price decision is not a measurement of heating state.")
                    Text("The Heating page shows controller-check freshness and warns if saved recovery needs attention. Homely state is reported separately from price permission. Temperature is managed by Homely and does not gate price policy. External heating changes pause the controller; saving policy releases that hold if automatic control is already active.")
                    Text("Heating reconnects with the saved address and Keychain key when you return to the page. Saving policy never activates automatic heating. The Automation switch persists ON/OFF. OFF stops heating and later leaves manual Homely use alone; pending shutdown is shown until confirmed. ON requires prior controller activation, an app confirmation and the next half-hour. The app cannot grant that initial activation. Android does not yet have the Heating page.")
                }

                Section("Index") {
                    Text("1. Conditional page buttons")
                    Text("2. Screen sizes and adaptive layout")
                    Text("3. Now button")
                    Text("4. Octopus Agile Prices")
                    Text("5. Solar Forecast and solar site")
                    Text("6. PV Forecast")
                    Text("7. Net Electricity Price")
                    Text("8. Cost Savings")
                    Text("9. App Settings and PV-array units")
                    Text("10. Cache, privacy and technical architecture")
                }

                Section("What the app does") {
                    Text("Agile Price Wheel combines Octopus Agile half-hour prices, solar irradiance forecasts, a PV Forecast, a solar-adjusted Net Electricity Price and forecast PV Cost Savings.")
                    Text("The first dashboard page is titled Octopus Agile Prices. The project and repository remain named AgilePriceWheel.")
                }

                Section("Conditional page buttons") {
                    Text("When Solar PV panels installed is on, the bottom navigation shows Prices, Solar, PV, Net, Save, Heating, Settings and Guide.")
                    Text("When Solar PV panels installed is off, PV, Net and Save are hidden, leaving Prices, Solar, Heating, Settings and Guide. Turning PV back on restores the three hidden pages immediately and keeps the saved PV-array and optimiser values.")
                    Text("Horizontal swipe navigation is intentionally disabled so dragging a wheel cannot accidentally change the main page.")
                }

                Section("Navigation symbols") {
                    Text("Prices uses a lightning bolt in a circle, Solar a sun, PV a simple filled lightning bolt, Net a pound symbol, Save a banknote, Settings sliders and Guide a book.")
                }

                Section("Screen sizes and adaptive layout") {
                    Text("The dashboard is designed to adapt to small and large iPhones and regular-width iPad layouts without device-specific fixed offsets.")
                    Text("Bottom navigation uses ViewThatFits. It prefers icon plus label, switches to a more compact icon-plus-label form when necessary, and can fall back to icons only on very narrow widths. Accessibility labels remain available in every form.")
                    Text("Metric-page and Settings headers also use ViewThatFits so they can change from a single horizontal row to a stacked layout when width is restricted.")
                    Text("Main metric content is centred and width-limited on wider displays. Compact-width screens use smaller margins. The Now control remains in normal layout flow rather than floating over content.")
                    Text("Very large Dynamic Type should still be checked during release testing because dense wheel-centre labels and metric cards have finite space.")
                }

                Section("Now button") {
                    Text("Octopus Agile Prices and Solar Forecast always have a Now button. PV Forecast, Net Electricity Price and Cost Savings also have Now when those pages are visible.")
                    Text("Tapping Now returns the shared selected date to today, loads today's source data if required and selects the half-hour containing the current time using validFrom ≤ now < validTo.")
                    Text("Now occupies reserved layout space so it should not cover descriptions, wheels or metric cards.")
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
                    Text("After obtaining coordinates, the app reverse-geocodes them to a familiar locality or town name. On iOS 26 and later this uses MapKit's modern reverse-geocoding request; earlier supported systems use the compatibility geocoder.")
                    Text("If a common name cannot be resolved, Current location is used as a fallback. The saved site name is editable without altering latitude or longitude.")
                    Text("Place/postcode search and manual coordinates remain available if location permission is denied or Location Services are unavailable.")
                }

                Section("PV Forecast") {
                    Text("PV Forecast estimates half-hour PV electrical output from the solar forecast plus configured array capacity, losses and inverter limit.")
                    Text("Estimated power = array kWp × (GHI ÷ 1000) × (1 − system-loss percentage), clipped to the configured inverter maximum when set. Energy = power × actual period duration.")
                    Text("Rated kWp takes priority; otherwise panel count × panel watts ÷ 1000 can provide array capacity.")
                    Text("If Solar PV panels installed is off, PV Forecast and its bottom navigation button are hidden. They return when PV is switched on again.")
                }

                Section("Net Electricity Price") {
                    Text("The Net Electricity Price wheel estimates the effective p/kWh cost of running the configured load after forecast PV reduces expected grid import.")
                    Text("Load energy = load kW × period hours; grid import = max(load energy − forecast PV, 0); slot cost = grid import × Agile price; net price = slot cost ÷ complete load energy.")
                    Text("The selected wheel sector also shows PV saving in pence and the Selected half-hour breakdown repeats it.")
                    Text("This page is hidden when Solar PV panels installed is off and returns when PV is enabled again.")
                }

                Section("Cost Savings") {
                    Text("Cost Savings is a separate half-hour wheel showing the import-cost saving created by forecast PV generation.")
                    Text("Avoided grid import = min(forecast PV energy, configured load energy). PV cost saving = avoided grid import × Agile price.")
                    Text("The page shows each half-hour saving, forecast day saving, best half-hour, total avoided grid import and a selected-period breakdown.")
                    Text("Surplus PV export income is not included. Negative Agile prices can produce a negative saving.")
                    Text("This page is hidden when Solar PV panels installed is off and returns when PV is enabled again.")
                }

                Section("PV-array units") {
                    Text("PV numeric fields keep their engineering units visible beside the editable value.")
                    Text("Rated peak power: kWp. Panel rating: W. Panel tilt: °. Azimuth: °. Inverter maximum AC output: kW. Estimated system losses: %.")
                    Text("Number of panels is dimensionless. Unit labels are display-only.")
                }

                Section("App Settings") {
                    Text("App Settings centralises Agile tariff/day controls, source refresh, solar site, PV availability, Solar PV array settings and optimiser load.")
                    Text("When Solar PV panels installed is off, PV, Net and Save disappear from bottom navigation; PV-array and optimiser controls are disabled; Solar Forecast stays active; saved values are retained. Turning PV back on restores the three pages immediately.")
                    Text("Azimuth convention: 0° North, 90° East, 180° South, 270° West.")
                }

                Section("Server, cache and offline use") {
                    Text("Agile and solar source data are cached locally after successful downloads.")
                    Text("PV Forecast, Net Electricity Price and Cost Savings are local derived calculations and can be recalculated from cached source data when required settings are present.")
                    Text("This indexed User Guide is bundled into the app and remains available offline.")
                }

                Section("Privacy") {
                    Text("The public tariff/rate features do not require Octopus login credentials, API key, MPAN, meter serial number or payment information.")
                    Text("Location permission is requested only when Use Current Location is tapped. Coordinates are stored locally, reverse-geocoded by Apple to obtain a readable site name, and sent to Open-Meteo for solar forecast requests. The app does not continuously monitor location.")
                }

                Section("Technical architecture") {
                    Text("SwipeDashboardView coordinates the defined pages, conditional bottom navigation, adaptive header/navigation layout, Now behaviour and PV-dependent visibility.")
                    Text("SolarSiteSettingsView uses Core Location for explicit one-shot location fixes and MapKit reverse geocoding on iOS 26 and later, with a legacy compatibility path for earlier systems.")
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
