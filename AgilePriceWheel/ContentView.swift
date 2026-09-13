import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: AgileViewModel

    @State private var showingSettings = false
    @State private var showingInfo = false
    @State private var selectedTab: AppTab = .prices

    private let accent = Color.orange
    private let navy = Color(red: 0.015, green: 0.10, blue: 0.17)
    private let card = Color(red: 0.02, green: 0.13, blue: 0.21)
    private let line = Color(red: 0.06, green: 0.30, blue: 0.43)

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.01, green: 0.09, blue: 0.16),
                    Color(red: 0.015, green: 0.13, blue: 0.21),
                    Color(red: 0.01, green: 0.08, blue: 0.14)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    appHeader

                    if model.isLoadingRates && model.rates.isEmpty {
                        ProgressView("Loading half-hour prices…")
                            .tint(accent)
                            .foregroundStyle(accent)
                            .frame(maxWidth: .infinity, minHeight: 420)
                    } else if !model.rates.isEmpty {
                        switch selectedTab {
                        case .prices:
                            pricesPage
                        case .chart:
                            chartPage
                        case .details:
                            detailsPage
                        }
                    } else if let error = model.errorMessage {
                        unavailable(error)
                    }

                    tabBar
                        .padding(.top, 4)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
            }
        }
        .preferredColorScheme(.dark)
        .task { await model.start() }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
                .environmentObject(model)
                .preferredColorScheme(.dark)
        }
        .sheet(isPresented: $showingInfo) {
            InfoView()
                .preferredColorScheme(.dark)
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

    private var appHeader: some View {
        VStack(spacing: 3) {
            HStack(alignment: .center) {
                Button {
                    showingSettings = true
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 26, weight: .medium))
                        .foregroundStyle(accent)
                        .frame(width: 42, height: 42)
                }

                Spacer()

                Text("Agile Price Wheel")
                    .font(.system(size: 29, weight: .semibold, design: .rounded))
                    .foregroundStyle(accent)
                    .minimumScaleFactor(0.75)
                    .lineLimit(1)

                Spacer()

                Button {
                    showingInfo = true
                } label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 27, weight: .medium))
                        .foregroundStyle(accent)
                        .frame(width: 42, height: 42)
                }
            }

            Text("Octopus Agile — \(dayLabel)")
                .font(.system(size: 17, weight: .medium, design: .rounded))
                .foregroundStyle(accent.opacity(0.92))

            dataSourceBadge
        }
        .padding(.top, 4)
    }

    private var dataSourceBadge: some View {
        VStack(spacing: 3) {
            HStack(spacing: 6) {
                Image(systemName: dataSourceIcon)
                    .font(.system(size: 11, weight: .semibold))

                Text(model.dataSourceLabel)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                if model.isLoadingRates {
                    ProgressView()
                        .controlSize(.mini)
                        .tint(dataSourceColour)
                }
            }
            .foregroundStyle(dataSourceColour)

            if let message = model.syncMessage, !message.isEmpty {
                Text(message)
                    .font(.system(size: 10, weight: .regular, design: .rounded))
                    .foregroundStyle(.white.opacity(0.65))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 2)
    }

    private var dataSourceColour: Color {
        switch model.dataOrigin {
        case .none:
            return .secondary
        case .server:
            return .green
        case .localCache:
            return .orange
        }
    }

    private var dataSourceIcon: String {
        switch model.dataOrigin {
        case .none:
            return "questionmark.circle"
        case .server:
            return "network"
        case .localCache:
            return "internaldrive"
        }
    }

    private var pricesPage: some View {
        VStack(spacing: 12) {
            PriceWheelView(rates: model.rates, selectedRateID: $model.selectedRateID)
                .frame(maxWidth: 560)
                .padding(.top, 2)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                summaryTile(
                    title: "Lowest price",
                    value: model.minPrice,
                    colour: colour(for: model.minPrice),
                    timeRange: timeRange(for: model.minPrice)
                )

                summaryTile(
                    title: "Highest price",
                    value: model.maxPrice,
                    colour: colour(for: model.maxPrice),
                    timeRange: timeRange(for: model.maxPrice)
                )

                summaryTile(
                    title: "Average price",
                    value: model.averagePrice,
                    colour: colour(for: model.averagePrice),
                    showsDot: false
                )

                selectedSlotTile
            }
        }
    }

    private var chartPage: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeading("Half-hour prices")

            ForEach(model.rates) { rate in
                HStack(spacing: 10) {
                    Text("\(time(rate.validFrom))–\(time(rate.validTo))")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.white.opacity(0.86))
                        .frame(width: 92, alignment: .leading)

                    GeometryReader { proxy in
                        let width = barWidth(for: rate.valueIncVAT, available: proxy.size.width)
                        RoundedRectangle(cornerRadius: 5)
                            .fill(colour(for: rate.valueIncVAT))
                            .frame(width: width, height: 14)
                    }
                    .frame(height: 14)

                    Text(String(format: "%.1fp", rate.valueIncVAT))
                        .font(.caption.bold().monospacedDigit())
                        .foregroundStyle(accent)
                        .frame(width: 50, alignment: .trailing)
                }
                .padding(.vertical, 2)
            }
        }
        .padding(14)
        .background(card.opacity(0.78), in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(line.opacity(0.75), lineWidth: 1.2))
    }

    private var detailsPage: some View {
        VStack(spacing: 12) {
            if let rate = model.selectedRate {
                detailPanel(
                    title: "Selected half hour",
                    rows: [
                        ("Time", "\(time(rate.validFrom))–\(time(rate.validTo))"),
                        ("Including VAT", String(format: "%.2f p/kWh", rate.valueIncVAT)),
                        ("Excluding VAT", String(format: "%.2f p/kWh", rate.valueExcVAT)),
                        ("Price band", PriceColourScale(rates: model.rates).band(for: rate.valueIncVAT))
                    ]
                )
            }

            if let tariff = model.selectedTariff {
                detailPanel(
                    title: "Tariff",
                    rows: [
                        ("Product", tariff.productName),
                        ("Region", tariff.regionName),
                        ("Tariff code", tariff.tariffCode),
                        ("Payment", tariff.paymentMethod.replacingOccurrences(of: "_", with: " ").capitalized),
                        ("Standing charge", tariff.standingChargeIncVAT.map { String(format: "%.2f p/day", $0) } ?? "Not supplied")
                    ]
                )
            }

            Button {
                showingSettings = true
            } label: {
                Label("Change tariff or day", systemImage: "gearshape")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
            }
            .buttonStyle(.plain)
            .foregroundStyle(accent)
            .background(card, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(line, lineWidth: 1.2))
      }
    }

    private func summaryTile(
        title: String,
        value: Double?,
        colour: Color,
        timeRange: String? = nil,
        showsDot: Bool = true
    ) -> some View {
        HStack(spacing: 9) {
            if showsDot {
                Circle()
                    .fill(colour)
                    .frame(width: 14, height: 14)
                    .shadow(color: colour.opacity(0.5), radius: 4)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(accent.opacity(0.88))

                if let value {
                    Text(String(format: "%.1f p/kWh", value))
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.colour)
                        .lineLimit(1)

                    if let timeRange {
                        Text(timeRange)
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.white.opacity(0.66))
                            .lineLimit(1)
                    }
                } else {
                    Text("—")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(13)
        .frame(maxWidth: .infinity, minHeight: 78)
        .background(card.opacity(0.92), in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(line.opacity(0.8), lineWidth: 1.2))
    }

    private var selectedSlotTile: some View {
        HStack(spacing: 9) {
            Circle()
                .fill(colour(for: model.selectedRate?.valueIncVAT))
                .frame(width: 14, height: 14)

            VStack(alignment: .leading, spacing: 2) {
                Text("Chosen slot")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(accent.opacity(0.88))

                if let rate = model.selectedRate {
                    Text(String(format: "%.1f p/kWh", rate.valueIncVAT))
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.orange)

                    Text("\(time(rate.validFrom))–$(time(rate.validTo))")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white.opacity(0.66))
                }
            }

            Spacer(minLength: 0)
        }
        .padding(13)
        .frame(maxWidth: .infinity, minHeight: 78)
        .background(card.opacity(0.92), in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(line.opacity(0.8), lineWidth: 1.2))
    }

    private var tabBar: some View {
        HStack(spacing: 6) {
            tabButton(.prices, title: "Prices")
            tabButton(.chart, title: "Chart")
            tabButton(.details, title: "Details")
        }
        .padding(6)
        .background(card.opacity(0.72), in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(line.opacity(0.9), lineWidth: 1.2))
    }

    private func tabButton(_ tab: AppTab, title: String) -> some View {
        Button {
            withAnimation(.naseStretch(duration: 0.18)) {
                selectedTab = tab
            }
        } label: {
            Text(title)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(accent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    selectedTab == tab ? Color.white.opacity(0.18) : .clear,
                    in: RoundedRectangle(cornerRadius: 14)
                )
        }
        .buttonStyle(.plain)
    }

    private func detailPanel(title: String, rows: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeading(title)

            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(alignment: .top) {
                    Text(row.0)
                        .foregroundStyle(.white.opacity(0.62))
                    Spacer(minLength: 12)
                    Text(row.1)
                        .foregroundStyle(accent)
                        .multilineTextAlignment(.trailing)
                }
                .font(.subheadline)
            }
        }
        .padding(16)
        .background(card.opacity(0.78), in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(line.opacity(0.8), lineWidth: 1.2))
    }

    private func sectionHeading(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 20, weight: .semibold, design: .rounded))
            .foregroundStyle(accent)
    }

    private func unavailable(_ message: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "bolt.trianglebadge.exclamationmark")
                .font(.system(size: 42))
                .foregroundStyle(accent)
            Text("No prices")
                .font(.title2.bold())
                .foregroundStyle(accent)
            Text(message)
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
            Button("Open settings") { showingSettings = true }
                .buttonStyle(.bordered)
                .tint(accent)
        }
        .padding(.vertical, 70)
    }

    private var dayLabel: String {
        let calendar = Calendar.uk
        if calendar.isDateInToday(model.selectedDate) { return "Today" }
        if calendar.isDateInTomorrow(model.selectedDate) { return "Tomorrow" }
        return model.selectedDate.formatted(.dateTime.day().month(.abbreviated))
    }

    private func timeRange(for value: Double?) -> String? {
        guard let value,
              let rate = model.rates.first(where: { $0.valueIncVAT == value }) else { return nil }
        return "\(time(rate.validFrom))–(\(time(rate.validTo))"
    }

    private func colour(for value: Double?) -> Color {
        guard let value else { return .gray }
        return PriceColourScale(rates: model.rates).colour(for: value)
    }

    private func barWidth(for value: Double, available: CGFloat) -> CGFloat {
        guard let minPrice = model.minPrice, let maxPrice = model.maxPrice, maxPrice > minPrice else {
            return available * 0.55
        }
        let normalized = (value - minPrice) / (maxPrice - minPrice)
        return Swift.max(12, available * CGFloat(0.15 + normalized * 0.85))
    }

    private func time(_ date: Date) -> String {
        date.formatted(.dateTime.hour().minute().timeZone(.omitted))
    }
}

private enum AppTab {
    case prices
    case chart
    case details
}

private struct SettingsView: View {
    @EnvironmentObject private var model: AgileViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingTariffs = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Tariff") {
                    Button {
                        showingTariffs = true
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(model.selectedTariff?.regionName ?? "Choose tariff")
                                if let tariff = model.selectedTariff {
                                    Text(tariff.tariffCode)
                                        .font(.caption.monospaced())
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Day") {
                    DatePicker("Prices for", selection: $model.selectedDate, displayedComponents: .date)
                        .onChange(of: model.selectedDate) { _, _ in
                            Task { await model.loadRates() }
                        }
                }

                Section {
                    Button {
                        Task { await model.refresh() }
                    } label: {
                        Label("Refresh from Octopus", systemImage: "arrow.clockwise")
                    }
                    .disabled(model.selectedTariff == nil || model.isLoadingRates)
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showingTariffs) {
                TariffPickerView()
                    .environmentObject(model)
            }
        }
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
                                        Text(String(format: "Standing charge %.2fp/day", standing))
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
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

private struct InfoView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Price wheel") {
                    Text("Each coloured sector is one Agile half-hour price. Green is relatively cheaper and red is relatively more expensive for the selected day. Negative prices are shown blue.")
                    Text("Touch or drag around the wheel to inspect an individual half-hour period.")
                }

                Section("Prices") {
                    Text("Displayed unit prices include VAT unless specifically marked as excluding VAT.")
                    Text("The wheel supports daylight-saving days with 46 or 50 half-hour periods as well as normal 48-period days.")
                }
            }
            .navigationTitle("About")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AgileViewModel())
}
