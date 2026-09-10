import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: AgileViewModel
    @State private var showingTariffs = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    headerCard
                    controls

                    if model.isLoadingRates && model.rates.isEmpty {
                        ProgressView("Loading half-hour prices…")
                            .frame(maxWidth: .infinity, minHeight: 300)
                    } else if !model.rates.isEmpty {
                        PriceWheelView(rates: model.rates, selectedRateID: $model.selectedRateID)
                            .frame(maxWidth: 520)
                            .padding(.horizontal, 8)

                        detailCard
                        summaryCard
                        legend
                    } else if let error = model.errorMessage {
                        ContentUnavailableView("No prices", systemImage: "bolt.trianglebadge.exclamationmark", description: Text(error))
                            .padding(.vertical, 40)
                    }
                }
                .padding()
            }
            .navigationTitle("Agile Price Wheel")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await model.loadRates() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(model.selectedTariff == nil || model.isLoadingRates)
                }
            }
            .task { await model.start() }
            .sheet(isPresented: $showingTariffs) {
                TariffPickerView()
                    .environmentObject(model)
            }
            .alert("Octopus API", isPresented: Binding(
                get: { model.errorMessage != nil && !model.rates.isEmpty },
                set: { if !$0 { model.errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { model.errorMessage = nil }
            } message: {
                Text(model.errorMessage ?? "Unknown error")
            }
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(model.selectedTariff?.displayName ?? "Choose an Agile tariff")
                .font(.headline)
            if let tariff = model.selectedTariff {
                Text(tariff.tariffCode)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var controls: some View {
        VStack(spacing: 12) {
            Button {
                showingTariffs = true
            } label: {
                HStack {
                    Label("Tariff", systemImage: "list.bullet.rectangle")
                    Spacer()
                    Text(model.selectedTariff?.regionName ?? "Select")
                        .foregroundStyle(.secondary)
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)

            Divider()

            DatePicker("Day", selection: $model.selectedDate, displayedComponents: .date)
                .onChange(of: model.selectedDate) { _, _ in
                    Task { await model.loadRates() }
                }
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var detailCard: some View {
        Group {
            if let rate = model.selectedRate {
                let scale = PriceColourScale(rates: model.rates)
                VStack(spacing: 8) {
                    Text("\(time(rate.validFrom))–\(time(rate.validTo))")
                        .font(.title2.bold())
                    Text("\(rate.valueIncVAT, specifier: "%.2f") p/kWh")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                    Text("including VAT · \(scale.band(for: rate.valueIncVAT))")
                        .foregroundStyle(.secondary)
                    Text("Ex VAT: \(rate.valueExcVAT, specifier: "%.2f") p/kWh")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(rate.validFrom.formatted(date: .complete, time: .omitted))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(scale.colour(for: rate.valueIncVAT).opacity(0.16), in: RoundedRectangle(cornerRadius: 18))
            }
        }
    }

    private var summaryCard: some View {
        HStack {
            stat("Lowest", model.minPrice)
            Divider().frame(height: 38)
            stat("Average", model.averagePrice)
            Divider().frame(height: 38)
            stat("Highest", model.maxPrice)
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var legend: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Colour scale")
                .font(.headline)
            LinearGradient(
                colors: [Color(hue: 0.33, saturation: 0.82, brightness: 0.92), .yellow, .orange, .red],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(height: 12)
            .clipShape(Capsule())
            HStack {
                Text("Lower cost")
                Spacer()
                Text("Higher cost")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            Text("Colours are relative to the selected day's prices. Negative prices are shown blue. Touch or drag around the wheel to inspect each half hour.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom)
    }

    private func stat(_ label: String, _ value: Double?) -> some View {
        VStack(spacing: 3) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            if let value {
                Text("\(value, specifier: "%.1f")p")
                    .font(.headline.monospacedDigit())
            } else {
                Text("—")
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func time(_ date: Date) -> String {
        date.formatted(.dateTime.hour().minute().timeZone(.omitted))
    }
}

private struct TariffPickerView: View {
    @EnvironmentObject private var model: AgileViewModel
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
            Group {
                if model.isLoadingTariffs && model.tariffs.isEmpty {
                    ProgressView("Loading available Agile tariffs…")
                } else {
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
                                    if let standing = tariff.standingChargeIncVAT {
                                        Text("Standing charge \(standing, specifier: "%.2f")p/day")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                if tariff.id == model.selectedTariff?.id {
                                    Image(systemName: "checkmark.circle.fill")
                                }
                            }
                        }
                    }
                    .searchable(text: $search, prompt: "Region, product or tariff code")
                }
            }
            .navigationTitle("Available Agile tariffs")
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

#Preview {
    ContentView()
        .environmentObject(AgileViewModel())
}
