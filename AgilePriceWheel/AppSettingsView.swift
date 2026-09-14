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

            Section {
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
            } header: {
                Text("Solar forecast site")
            } footer: {
                Text("The site coordinates are used for the half-hour irradiance forecast shown on the Solar Forecast page. The irradiance page remains available even if no PV panels are installed.")
            }

            Section {
                Toggle("Solar PV panels installed", isOn: $settings.hasPVPanelsInstalled)
            } header: {
                Text("Solar PV availability")
            } footer: {
                Text("Turn this off for a property without PV panels. PV-array settings and the net-price optimiser controls are then disabled, while saved values are retained in case PV is enabled again later.")
            }

            Section {
                Group {
                    TextField("Array name", text: $settings.arrayName)

                    unitField("Rated peak power", text: $settings.peakPowerKWpText, unit: "kWp", keyboard: .decimalPad)

                    TextField("Number of panels", text: $settings.panelCountText)
                        .keyboardType(.numberPad)

                    unitField("Panel rating", text: $settings.panelPowerWattsText, unit: "W", keyboard: .decimalPad)

                    if let calculated = settings.calculatedPanelPeakKWp {
                        LabeledContent("Panels imply", value: String(format: "%.2f kWp", calculated))
                    }

                    unitField("Panel tilt from horizontal", text: $settings.tiltDegreesText, unit: "°", keyboard: .decimalPad)

                    unitField("Azimuth", text: $settings.azimuthDegreesText, unit: "°", keyboard: .decimalPad)

                    unitField("Inverter maximum AC output", text: $settings.inverterMaxKWText, unit: "kW", keyboard: .decimalPad)

                    unitField("Estimated system losses", text: $settings.systemLossPercentText, unit: "%", keyboard: .decimalPad)

                    TextField("Notes", text: $settings.notes, axis: .vertical)
                        .lineLimit(2...5)

                    if settings.hasArrayDetails {
                        Button("Clear PV array details", role: .destructive) {
                            settings.clearSolarArray()
                        }
                    }
                }
                .disabled(!settings.hasPVPanelsInstalled)
                .opacity(settings.hasPVPanelsInstalled ? 1.0 : 0.38)
            } header: {
                Text("Solar PV array")
            } footer: {
                if settings.hasPVPanelsInstalled {
                    Text("Units remain visible beside each PV value while editing: kWp for rated array power, W for panel rating, degrees for tilt/azimuth, kW for inverter output and % for system losses. These details feed the PV Forecast and Net Electricity Price pages. Azimuth uses 0° = North, 90° = East, 180° = South and 270° = West. Tilt and azimuth are stored but are not yet applied by the current GHI-based generation model.")
                } else {
                    Text("PV-array options are disabled because Solar PV panels installed is turned off.")
                }
            }

            Section {
                Group {
                    TextField("Controllable load power (kW)", text: $settings.optimiserLoadKWText)
                        .keyboardType(.decimalPad)

                    if let loadKW = settings.effectiveOptimiserLoadKW {
                        LabeledContent("30-minute load energy", value: String(format: "%.3f kWh", loadKW * 0.5))
                    }
                }
                .disabled(!settings.hasPVPanelsInstalled)
                .opacity(settings.hasPVPanelsInstalled ? 1.0 : 0.38)
            } header: {
                Text("Net price optimiser")
            } footer: {
                if settings.hasPVPanelsInstalled {
                    Text("This is the load used by the Net Electricity Price wheel. It defaults to 3.0 kW to match the established nightly email optimiser. Forecast PV is offset against this load before the remaining grid import is costed at the Agile rate.")
                } else {
                    Text("The net-price optimiser is disabled when no PV panels are installed.")
                }
            }

            Section("Stored data") {
                LabeledContent("PV panels", value: settings.hasPVPanelsInstalled ? "Installed" : "Not installed")
                LabeledContent("Agile source", value: agileModel.dataSourceLabel)
                LabeledContent("Solar source", value: solarModel.dataSourceLabel)

                Text("Tariff selection, site coordinates, the PV-installed setting, PV-array settings and optimiser load are stored locally on this device. Previously downloaded electricity and solar data are cached for offline use.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Navigation") {
                Label("Swipe right to return to Net Electricity Price", systemImage: "arrow.right")
                    .foregroundStyle(.secondary)
                Label("Swipe left to open the User Guide", systemImage: "arrow.left")
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

    @ViewBuilder
    private func unitField(
        _ title: String,
        text: Binding<String>,
        unit: String,
        keyboard: UIKeyboardType
    ) -> some View {
        HStack(spacing: 10) {
            Text(title)
            Spacer(minLength: 12)
            TextField("", text: text)
                .keyboardType(keyboard)
                .multilineTextAlignment(.trailing)
                .frame(minWidth: 72, idealWidth: 95, maxWidth: 120)
            Text(unit)
                .foregroundStyle(.secondary)
                .frame(minWidth: 30, alignment: .leading)
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
