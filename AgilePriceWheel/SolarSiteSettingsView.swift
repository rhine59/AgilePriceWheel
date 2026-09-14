import SwiftUI
import CoreLocation
import Combine
import MapKit

struct SolarSiteSettingsView: View {
    @ObservedObject var solarModel: SolarForecastModel
    let selectedDate: Date

    @Environment(\.dismiss) private var dismiss
    @StateObject private var locationProvider = SolarSiteLocationProvider()
    @State private var searchText = ""
    @State private var latitudeText = ""
    @State private var longitudeText = ""
    @State private var siteNameText = ""
    @State private var manualError: String?
    @State private var isResolvingPlaceName = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if let site = solarModel.site {
                        TextField("Site name", text: $siteNameText)
                            .textInputAutocapitalization(.words)
                            .autocorrectionDisabled()
                            .onSubmit { saveSiteName() }

                        Button("Save site name") {
                            saveSiteName()
                        }
                        .disabled(siteNameText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || siteNameText == site.name)

                        LabeledContent("Latitude", value: String(format: "%.6f", site.latitude))
                        LabeledContent("Longitude", value: String(format: "%.6f", site.longitude))

                        Button("Clear solar site", role: .destructive) {
                            solarModel.clearSite()
                            siteNameText = ""
                            latitudeText = ""
                            longitudeText = ""
                        }
                    } else {
                        Text("No solar forecast site has been set.")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Current solar site")
                } footer: {
                    Text("The site name is only a label for display. Editing it does not change the saved latitude or longitude.")
                }

                Section {
                    Button {
                        locationProvider.findCurrentLocation()
                    } label: {
                        HStack {
                            Label("Use Current Location", systemImage: "location.fill")
                            if locationProvider.isLocating || isResolvingPlaceName {
                                Spacer()
                                ProgressView()
                            }
                        }
                    }
                    .disabled(locationProvider.isLocating || isResolvingPlaceName)

                    if let locationError = locationProvider.errorMessage {
                        Text(locationError)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                } header: {
                    Text("Current location")
                } footer: {
                    Text("Uses the iPhone or iPad location only when you tap Use Current Location. The app then reverse-geocodes the coordinates to a familiar place name such as the locality or town and saves that as the solar-site name. You can edit the name afterwards. If no common place name can be found, Current location is used as a fallback. You can deny location access and continue to use place/postcode search or manual coordinates instead.")
                }

                Section {
                    TextField("Place or postcode", text: $searchText)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()

                    Button {
                        Task { await solarModel.searchSites(searchText) }
                    } label: {
                        HStack {
                            Label("Find location", systemImage: "magnifyingglass")
                            if solarModel.isSearchingSites {
                                Spacer()
                                ProgressView()
                            }
                        }
                    }
                    .disabled(searchText.trimmingCharacters(in: .whitespacesAndNewlines).count < 2 || solarModel.isSearchingSites)

                    ForEach(solarModel.searchResults) { result in
                        Button {
                            Task {
                                await solarModel.setSite(result.siteLocation, for: selectedDate)
                                fillManualFields()
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(result.displayName)
                                    .foregroundStyle(.primary)
                                Text(String(format: "%.5f, %.5f", result.latitude, result.longitude))
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                } header: {
                    Text("Find site")
                } footer: {
                    Text("Search is provided by Open-Meteo geocoding. Choose the result that best represents the solar installation site. The saved site name can be edited above without changing its coordinates.")
                }

                Section {
                    TextField("Latitude", text: $latitudeText)
                        .keyboardType(.numbersAndPunctuation)
                    TextField("Longitude", text: $longitudeText)
                        .keyboardType(.numbersAndPunctuation)

                    if let manualError {
                        Text(manualError)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    Button {
                        saveManualCoordinates()
                    } label: {
                        Label("Set latitude & longitude", systemImage: "mappin.and.ellipse")
                    }
                } header: {
                    Text("Manual coordinates")
                } footer: {
                    Text("Latitude must be between −90 and 90. Longitude must be between −180 and 180. The coordinates are stored on this device and used only to request the solar irradiance forecast.")
                }

                Section("Solar forecast") {
                    Button {
                        Task { await solarModel.refresh(for: selectedDate) }
                    } label: {
                        Label("Refresh solar forecast", systemImage: "arrow.clockwise")
                    }
                    .disabled(solarModel.site == nil || solarModel.isLoading)

                    Text("Forecast values are global horizontal irradiance (shortwave solar radiation), displayed in watts per square metre for each half-hour of the same day as the Agile price wheel.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Solar Site")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear { fillManualFields() }
            .onChange(of: solarModel.site) { _, _ in fillManualFields() }
            .onChange(of: locationProvider.fix) { _, fix in
                guard let fix else { return }

                latitudeText = String(format: "%.6f", fix.latitude)
                longitudeText = String(format: "%.6f", fix.longitude)
                manualError = nil
                isResolvingPlaceName = true

                Task {
                    let resolvedName = await commonName(latitude: fix.latitude, longitude: fix.longitude)
                    await solarModel.setManualSite(
                        name: resolvedName,
                        latitude: fix.latitude,
                        longitude: fix.longitude,
                        for: selectedDate
                    )
                    siteNameText = resolvedName
                    isResolvingPlaceName = false
                    locationProvider.consumeFix()
                }
            }
        }
    }

    private func fillManualFields() {
        guard let site = solarModel.site else { return }
        siteNameText = site.name
        latitudeText = String(format: "%.6f", site.latitude)
        longitudeText = String(format: "%.6f", site.longitude)
    }

    private func saveSiteName() {
        guard let site = solarModel.site else { return }
        let trimmed = siteNameText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            siteNameText = site.name
            return
        }

        Task {
            await solarModel.setManualSite(
                name: trimmed,
                latitude: site.latitude,
                longitude: site.longitude,
                for: selectedDate
            )
            siteNameText = trimmed
        }
    }

    private func saveManualCoordinates() {
        let normalizedLat = latitudeText.replacingOccurrences(of: ",", with: ".")
        let normalizedLon = longitudeText.replacingOccurrences(of: ",", with: ".")

        guard let latitude = Double(normalizedLat),
              let longitude = Double(normalizedLon),
              (-90...90).contains(latitude),
              (-180...180).contains(longitude) else {
            manualError = "Enter valid latitude and longitude values."
            return
        }

        manualError = nil
        let preferredName = siteNameText.trimmingCharacters(in: .whitespacesAndNewlines)
        Task {
            await solarModel.setManualSite(
                name: preferredName.isEmpty ? "Custom site" : preferredName,
                latitude: latitude,
                longitude: longitude,
                for: selectedDate
            )
            fillManualFields()
        }
    }

    private func commonName(latitude: Double, longitude: Double) async -> String {
        let location = CLLocation(latitude: latitude, longitude: longitude)

        if #available(iOS 26.0, *) {
            guard let request = MKReverseGeocodingRequest(location: location) else {
                return "Current location"
            }
            request.preferredLocale = Locale(identifier: "en_GB")

            do {
                let mapItems = try await request.mapItems
                guard let mapItem = mapItems.first else {
                    return "Current location"
                }

                let candidates = [
                    mapItem.addressRepresentations?.cityName,
                    mapItem.addressRepresentations?.cityWithContext,
                    mapItem.name
                ]

                if let name = candidates
                    .compactMap({ $0?.trimmingCharacters(in: .whitespacesAndNewlines) })
                    .first(where: { !$0.isEmpty }) {
                    return name
                }
            } catch {
                return "Current location"
            }

            return "Current location"
        } else {
            return await legacyCommonName(for: location)
        }
    }

    @available(iOS, introduced: 5.0, obsoleted: 26.0)
    private func legacyCommonName(for location: CLLocation) async -> String {
        let geocoder = CLGeocoder()

        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            guard let placemark = placemarks.first else { return "Current location" }

            let candidates = [
                placemark.locality,
                placemark.subLocality,
                placemark.subAdministrativeArea,
                placemark.administrativeArea,
                placemark.name
            ]

            if let name = candidates
                .compactMap({ $0?.trimmingCharacters(in: .whitespacesAndNewlines) })
                .first(where: { !$0.isEmpty }) {
                return name
            }
        } catch {
            return "Current location"
        }

        return "Current location"
    }
}

private struct SolarSiteLocationFix: Equatable {
    let latitude: Double
    let longitude: Double
}

@MainActor
private final class SolarSiteLocationProvider: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published private(set) var isLocating = false
    @Published private(set) var fix: SolarSiteLocationFix?
    @Published private(set) var errorMessage: String?

    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func findCurrentLocation() {
        errorMessage = nil
        fix = nil

        switch manager.authorizationStatus {
        case .notDetermined:
            isLocating = true
            manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            requestLocation()
        case .denied, .restricted:
            errorMessage = "Location access is unavailable. Check Location Services and Agile Price Wheel permission in Settings, or use place/postcode search or manual coordinates."
        @unknown default:
            errorMessage = "Current location is unavailable. Use place/postcode search or manual coordinates instead."
        }
    }

    func consumeFix() {
        fix = nil
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            if isLocating {
                requestLocation()
            }
        case .denied, .restricted:
            isLocating = false
            errorMessage = "Location access was not allowed or Location Services are unavailable. You can still use place/postcode search or manual coordinates."
        case .notDetermined:
            break
        @unknown default:
            isLocating = false
            errorMessage = "Current location is unavailable. Use place/postcode search or manual coordinates instead."
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        isLocating = false

        guard let location = locations.last else {
            errorMessage = "No current location was returned. Try again, or use place/postcode search or manual coordinates."
            return
        }

        fix = SolarSiteLocationFix(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude
        )
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        isLocating = false
        errorMessage = "Could not determine the current location. \(error.localizedDescription)"
    }

    private func requestLocation() {
        isLocating = true
        manager.requestLocation()
    }
}
