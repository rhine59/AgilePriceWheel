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
                    Text("Agile Price Wheel displays Octopus Energy Agile electricity prices as an interactive half-hour wheel and adds a same-day solar irradiance forecast for a configured site.")
                    Text("The app discovers currently available Agile import tariffs from the public Octopus Energy API rather than relying on one hard-coded product, and obtains solar irradiance forecasts from Open-Meteo.")
                }

                Section("Accessing this guide") {
                    Text("Tap the information button at the top-right of either the electricity-price screen or the solar screen to open this guide. It is bundled with the app and therefore remains available offline.")
                }

                Section("Using the price wheel") {
                    Text("Touch or drag around the wheel to select a half-hour. The selected price and start/end time are shown in the centre and in the Chosen slot tile.")
                    Text("The Lowest price and Highest price tiles show both the price and the half-hour in which it applies. Average price is calculated from all published periods for the selected day.")
                }

                Section("Swipe to solar forecast") {
                    Text("From the electricity-price screen, swipe left to open the solar forecast for the same selected calendar day. Swipe right on the solar screen to return to electricity prices.")
                    Text("The solar wheel uses one sector per half-hour and shows forecast global horizontal irradiance (GHI), also called shortwave solar radiation, in watts per square metre (W/m²). Touch or drag around the solar wheel to inspect an individual half-hour.")
                }

                Section("Solar colours and values") {
                    Text("Night-time or near-zero irradiance periods are dark. Daylight sectors become progressively brighter yellow/orange as forecast irradiance rises relative to the highest value of that day.")
                    Text("The solar summary tiles show peak irradiance and its time, daylight-average irradiance, the selected half-hour and the coordinates used for the forecast.")
                }

                Section("Setting the solar site") {
                    Text("On the solar screen tap the gear button to open Solar Site settings. Search for a place name or postcode and choose the best matching result, or enter latitude and longitude manually.")
                    Text("The selected site name and coordinates are stored on the device. Location search uses the Open-Meteo geocoding service. The app does not require access to the iPhone's GPS location.")
                }

                Section("Price colours") {
                    Text("Positive electricity prices use a relative scale for the selected day: cheaper periods are green, progressing through yellow and orange to red for the most expensive periods. Negative prices are blue.")
                    Text("Because the price scale is relative to the selected day, a green sector means cheaper than the other periods shown; it is not a fixed universal price threshold.")
                }

                Section("Prices, Chart and Details") {
                    Text("Prices shows the interactive electricity wheel and summary tiles. Chart lists the day's half-hour prices visually. Details shows the selected half-hour and active tariff information including region, tariff code, payment method and standing charge when supplied by Octopus.")
                }

                Section("Tariff and day") {
                    Text("Use the gear button on the electricity screen to select the Agile tariff/region and calendar day. The selected tariff is remembered on the device. The solar screen always follows the same selected day.")
                    Text("The app uses Europe/London time. Normal days contain 48 half-hours; UK clock-change days can contain 46 or 50. Both electricity and solar views use the actual number of periods returned rather than assuming 48.")
                }

                Section("Server and local data") {
                    Text("SERVER DATA means the displayed information was obtained from its online source. LOCAL CACHE means the app is displaying a previously saved copy. Both electricity prices and solar forecasts show their own source status and update/save time.")
                    Text("Every successfully downloaded tariff list, tariff/day price set and site/day solar forecast is cached on the device for offline use.")
                }

                Section("Refresh") {
                    Text("Electricity Settings contains Refresh from Octopus. Solar Site settings contains Refresh solar forecast. Successful refreshes replace the displayed data and update the corresponding cache; failed refreshes do not discard an existing cached copy.")
                }

                Section("Offline limitations") {
                    Text("Offline mode can only show data that has already been downloaded and cached. A price day or solar day that has never been fetched cannot be created while offline.")
                    Text("Solar cache entries are tied to the selected site coordinates and calendar day. Changing site coordinates requires a forecast for the new site before that site can be used offline.")
                }

                Section("Solar forecast source") {
                    Text("Solar forecasts use the Open-Meteo Forecast API 15-minute shortwave-radiation series. The app combines consecutive 15-minute values into half-hour values so they align with Agile settlement periods.")
                    Text("Open-Meteo describes shortwave radiation as global horizontal irradiance at the surface. The value is radiation power per square metre, not predicted electrical output from a PV array.")
                }

                Section("Octopus API") {
                    Text("The app uses the public Octopus Energy REST product and standard-unit-rate endpoints. These endpoints do not require your Octopus account number, API key, MPAN, meter serial number or login credentials.")
                }

                Section("Privacy and local storage") {
                    Text("The app does not need your Octopus login, account number, MPAN, meter serial number or payment information. The tariff and solar-site preferences are stored locally. Cached tariff metadata, prices and solar forecasts are stored as JSON beneath the app's Application Support directory.")
                    Text("The latitude and longitude you choose are sent to Open-Meteo only when obtaining a solar forecast. The current implementation discovers a site by place/postcode search or manual coordinates rather than requesting the phone's GPS position.")
                }

                Section("Technical architecture") {
                    Text("AgileViewModel coordinates OctopusAPI and AgileCacheStore. SolarForecastModel coordinates SolarForecastAPI and SolarForecastCache. SwipeDashboardView switches between ContentView and SolarForecastView while keeping both on the same selected calendar day.")
                    Text("The app is native Swift/SwiftUI with no third-party package dependencies. Networking uses URLSession and JSON decoding uses Codable/JSONDecoder.")
                }

                Section("Accuracy") {
                    Text("Electricity unit prices include VAT unless explicitly labelled otherwise. Solar W/m² values are weather-model forecasts, not measured site irradiance and not a guarantee of PV generation. Cloud and model uncertainty can materially change actual solar conditions.")
                    Text("Agile Price Wheel is independent and is not an official Octopus Energy or Open-Meteo application.")
                }

                Section("Documentation maintenance") {
                    Text("README.md in the GitHub repository is the comprehensive developer/technical reference. This in-app guide is the user-facing companion. Every future functional change must review and update both README.md and this DocumentationView.swift as part of the same change.")
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
