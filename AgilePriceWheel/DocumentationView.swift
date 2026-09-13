import SwiftUI

/// User-facing documentation shipped with the app.
///
/// IMPORTANT: Keep this guide in sync with README.md whenever application
/// behaviour, setup, data sources, caching, controls or dependencies change.
struct DocumentationView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("What Agile Price Wheel does") {
                    Text("Agile Price Wheel displays Octopus Energy Agile electricity prices as an interactive 24-hour wheel. Each sector represents one published half-hour settlement period.")
                    Text("The app discovers currently available Agile import tariffs from the public Octopus Energy API rather than relying on a single hard-coded Agile product.")
                }

                Section("Accessing this guide") {
                    Text("Tap the information button at the top-right of the main screen at any time to open this Guide & Documentation view. The guide is stored inside the app, so it remains available even when the phone has no network connection.")
                }

                Section("Using the price wheel") {
                    Text("Touch or drag around the wheel to select a half-hour. The selected price and its start/end time are shown in the centre and in the Chosen slot tile.")
                    Text("The Lowest price and Highest price tiles show both the price and the half-hour in which it applies. Average price is calculated from all published periods for the selected day.")
                }

                Section("Colours") {
                    Text("Positive prices use a relative scale for the selected day: cheaper periods are green, progressing through yellow and orange to red for the most expensive periods. Negative prices are blue.")
                    Text("Because the scale is relative to the selected day, a green sector means cheaper than the other periods shown; it is not a fixed universal price threshold.")
                }

                Section("Prices, Chart and Details") {
                    Text("Prices shows the interactive wheel and summary tiles. Chart lists the day's half-hour prices visually. Details shows the selected half-hour and the active tariff information, including region, tariff code, payment method and standing charge when supplied by Octopus.")
                }

                Section("Tariff and day") {
                    Text("Use the gear button to select an Agile tariff/region and calendar day. The selected tariff is remembered on the device. The app uses Europe/London time for UK tariff periods.")
                    Text("Normal days contain 48 half-hours. UK clock-change days can contain 46 or 50. The wheel uses the actual number of periods returned rather than assuming 48.")
                }

                Section("Server and local data") {
                    Text("SERVER DATA means the displayed prices were successfully obtained from Octopus. LOCAL CACHE means the app is displaying a previously saved copy because cached data was loaded or the server could not be reached. The status includes the relevant update/save time.")
                    Text("Every successfully downloaded tariff list and each tariff/day set of prices that you view is cached on the device. This allows previously downloaded information to remain usable without a network connection.")
                }

                Section("Refresh") {
                    Text("Open Settings and choose Refresh from Octopus to request fresh tariff information and prices. A successful refresh replaces the displayed data and updates the local cache. If refresh fails, existing cached data is retained rather than being discarded.")
                }

                Section("Offline limitations") {
                    Text("Offline mode can only show tariff/day combinations that have previously been downloaded and cached. A future day's prices cannot appear offline unless that day's data was successfully obtained from Octopus first.")
                    Text("If neither server data nor a cached copy exists for the selected tariff/day, the app shows a no-data/error state.")
                }

                Section("Octopus API") {
                    Text("The app uses the public Octopus Energy REST product and standard-unit-rate endpoints. These endpoints do not require your Octopus account number, API key, MPAN, meter serial number or login credentials.")
                    Text("An internet connection is required to discover new tariffs and retrieve prices that are not already cached.")
                }

                Section("Privacy and local storage") {
                    Text("The app does not need your Octopus login, account number, MPAN, meter serial number, payment information or location. The selected tariff is stored in UserDefaults. Cached tariff metadata and prices are stored as JSON beneath the app's Application Support directory.")
                }

                Section("Technical architecture") {
                    Text("AgileViewModel owns the UI state and coordinates OctopusAPI and AgileCacheStore. OctopusAPI performs asynchronous URLSession requests and JSON decoding. AgileCacheStore persists tariff and rate snapshots. ContentView presents the dashboard and PriceWheelView renders and handles interaction with the wheel.")
                    Text("The app is native Swift/SwiftUI and has no third-party package dependencies. It uses Apple Foundation, SwiftUI and Combine APIs.")
                }

                Section("Price accuracy") {
                    Text("Displayed unit prices include VAT unless explicitly labelled otherwise. Agile Price Wheel is an independent app and is not an official Octopus Energy application. For billing decisions, verify the tariff against your Octopus account.")
                }

                Section("Documentation maintenance") {
                    Text("README.md in the GitHub repository is the comprehensive developer/technical reference. This in-app guide is the user-facing companion. Any future change that affects features, controls, data handling, setup, dependencies, caching, networking or distribution must update both README.md and this in-app documentation in the same change.")
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
