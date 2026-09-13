import SwiftUI

struct AppSettingsView: View {
    @ObservedObject var agileModel: AgileViewModel
    @ObservedObject var solarModel: SolarForecastModel
    @ObservedObject var settings: AppSettingsStore

    @State private var showingTariffs = false
    @State private var showingSolarSite = false

    private let accent = Color.orange

    var body: some View {
        Form {
            Section("Agile electricity") {
                Button {
                    showingTariffs = true
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Tariff")
                                .foregroundStyle(.primary)
                            Text(agileModel.selectedTariff?.displayName ?? "Choose an Agile tariff")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.secondary)
                    }
                }

                DatePicker("Selected day", selection: $agileModel.selectedDate, displayedComponents: .date)
                    .onChange(of: agileModel.selectedDate) { _, _ in
                        Task { await agileModel.loadRates() }
                    }

                Button {
                    Task { await agileModel.refresh() }
                } label: {
                    Label("Refresh Agile prices", systemImage: "arrow.clockwise")
                }
                .disabled(agileModel.selectedTariff == nil || agileModel.isLoadingRates)
            }

            Section("Solar forecast site") {
                if let site = solarModel.site {
                    LabeledContent("Site", value: site.name)
                    LabeledContent("Latitude", value: String(format: "%.6f", site.latitude))
                    LabeledContent("Longitude", value: String(format: "%.6f", site.longitude))
                } else {
                    Text("No site configured")
                        .foregroundStyle(.secondary)
                }

                Button {
                    showingSolarSite = true
                } label: {
                    Label(solarModel.site == nil ? "Set solar site" : "Change solar site", systemImage: "mappin.and.ellipse")
                }

                Button {
                    Task { await solarModel.refresh(for: agileModel.selectedDate) }
                } label: {
                    Label("Refresh solar forecast", systemImage: "sun.max")
                }
                .disabled(solarModel.site == nil || solarModel.isLoading)
            } footer: {
                Text("The site coordinates are used for the half-hour irradiance forecast shown on the Solar Forecast page.")
            }

            Section("Solar PV array") {
                TextField("Array name", text: $settings.arrayName)

                TextField("Rated peak power (kWp)", text: $settings.peakPowerKWpText)
                    .keyboardType(.decimalPad)

                TextField("Number of panels", text: $settings.panelCountText)
                    .keyboardType(.numberPad)

                TextField("Panel rating (W each)", text: $settings.panelPowerWattsText)
                    .keyboardType(.decimalPad)

                if let calculated = settings.calculatedPanelPeakKWp {
                    LabeledContent("Panels imply", value: String(format: "%.2f kWp", calculated))
                }

                TextField("Panel tilt from horizontal (°)", text: $settings.tiltDegreesText)
                    .keyboardType(.decimalPad)

                TextField("Azimuth (°)", text: $settings.azimuthDegreesText)
                    .keyboardType(.decimalPad)

                TextField("Inverter maximum AC output (kW)", text: $settings.inverterMaxKWText)
                    .keyboardType(.decimalPad)

                TextField("Estimated system losses (%)", text: $settings.systemLossPercentText)
                    .keyboardType(.decimalPad)

                TextField("Notes", text: $settings.notes, axis: .vertical)
                    .lineLimit(2...5)

                if settings.hasArrayDetails {
                    Button("Clear PV array details", role: .destructive) {
                        settings.clearSolarArray()
                    }
                }
            } footer: {
                Text("These PV-array details are stored now for later use in predicted-generation calculations. They do not yet alter the W/m² irradiance forecast. Azimuth uses 0° = North, 90° = East, 180° = South and 270° = West.")
            }

            Section("Stored data") {
                LabeledContent("Agile source", value: agileModel.dataSourceLabel)
                LabeledContent("Solar source", value: solarModel.dataSourceLabel)

                Text("Tariff selection, site coordinates and PV-array settings are stored locally on this device. Previously downloaded electricity and solar data are cached for offline use.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Navigation") {
                Label("Swipe right to return to Solar Forecast", systemImage: "arrow.right")
                    .foregroundStyle(.secondary)
            }
        }
        .scrollContentBackground(.hidden)
        .tint(accent)
        .sheet(isPresented: $showingTariffs) {
            AppTariffPickerView(model: agileModel)
        }
        .sheet(isPresented: $showingSolarSite) {
            SolarSiteSettingsView(
                solarModel: solarModel,
                selectedDate: agileModel.selectedDate
            )
            .preferredColorScheme(.dark)
        }
    }
}

private struct AppTariffPickerView: View {
    @ObservedObject var model: AgileViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""

    private var filtered: [TariffOption] {
        guard !search.isEmpty else { return model.tariffs }
        return model.tariffs.filter {
            $0.productName.localizedCaseInsensitiveContains(search) ||
            $0.tariffCode.localizedCaseInsensitiveContains(search) ||
            $0.regionName.localizedCaseInsensitiveContains(search)
        }
    }

    var body: some View {
        NavigationStack {
            List(filtered) { tariff in
                Button {
                    Task {
                        await model.chooseTariff(tariff)
                        dismiss()
                    }
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(tariff.displayName)
                                .foregroundStyle(.primary)
                            Text(tariff.subtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if tariff.id == model.selectedTariff?.id {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.orange)
                        }
                    }
                }
            }
            .searchable(text: $search, prompt: "Region, product or tariff code")
            .navigationTitle("Agile Tariff")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await model.loadTariffs() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        }
    }
}
