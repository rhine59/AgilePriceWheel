import SwiftUI

struct SolarSiteSettingsView: View {
    @ObservedObject var solarModel: SolarForecastModel
    let selectedDate: Date

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var latitudeText = ""
    @State private var longitudeText = ""
    @State private var manualError: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Current solar site") {
                    if let site = solarModel.site {
                        LabeledContent("Name", value: site.name)
                        LabeledContent("Latitude", value: String(format: "%.6f", site.latitude))
                        LabeledContent("Longitude", value: String(format: "%.6f", site.longitude))

                        Button("Clear solar site", role: .destructive) {
                            solarModel.clearSite()
                            latitudeText = ""
                            longitudeText = ""
                        }
                    } else {
                        Text("No solar forecast site has been set.")
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Find site") {
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
                } footer: {
                    Text("Search is provided by Open-Meteo geocoding. Choose the result that best represents the solar installation site.")
                }

                Section("Manual coordinates") {
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
        }
    }

    private func fillManualFields() {
        guard let site = solarModel.site else { return }
        latitudeText = String(format: "%.6f", site.latitude)
        longitudeText = String(format: "%.6f", site.longitude)
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
        Task {
            await solarModel.setManualSite(
                latitude: latitude,
                longitude: longitude,
                for: selectedDate
            )
        }
    }
}
