import SwiftUI

/// One half-hour result from the Agile + forecast-PV optimiser.
///
/// This intentionally follows the same model used by the nightly energy email:
/// forecast PV is offset against a configured controllable load, the remaining
/// energy is bought from the grid at the Agile rate, and that slot cost is
/// expressed as an effective p/kWh price for the complete load.
struct NetPriceHalfHour: Identifiable, Hashable {
    let validFrom: Date
    let validTo: Date
    let agilePricePPerKWh: Double
    let loadEnergyKWh: Double
    let forecastGenerationKWh: Double
    let avoidedGridImportKWh: Double
    let gridImportKWh: Double
    let pvCostSavingPence: Double
    let slotCostPence: Double
    let effectivePricePPerKWh: Double

    var id: Date { validFrom }
}

struct NetEffectivePriceView: View {
    @ObservedObject var agileModel: AgileViewModel
    @ObservedObject var solarModel: SolarForecastModel
    @ObservedObject var settings: AppSettingsStore
    let openSettings: () -> Void

    @State private var selectedID: Date?

    private let accent = Color.orange
    private let card = Color(red: 0.02, green: 0.13, blue: 0.21)
    private let line = Color(red: 0.06, green: 0.30, blue: 0.43)

    private var results: [NetPriceHalfHour] {
        guard let loadKW = settings.effectiveOptimiserLoadKW,
              loadKW > 0,
              let peakKWp = settings.effectivePeakPowerKWp,
              peakKWp > 0,
              !agileModel.rates.isEmpty,
              !solarModel.forecast.isEmpty else { return [] }

        let solarByStart = Dictionary(uniqueKeysWithValues: solarModel.forecast.map { ($0.validFrom, $0) })

        return agileModel.rates.compactMap { rate in
            guard let solar = solarByStart[rate.validFrom] else { return nil }

            let hours = max(rate.validTo.timeIntervalSince(rate.validFrom) / 3600.0, 0)
            guard hours > 0 else { return nil }

            let irradianceFactor = max(solar.wattsPerSquareMetre, 0) / 1000.0
            let rawPowerKW = peakKWp * irradianceFactor
            let lossAdjustedKW = rawPowerKW * settings.generationLossFactor
            let generationPowerKW: Double
            if let inverterMax = settings.effectiveInverterMaxKW {
                generationPowerKW = min(lossAdjustedKW, inverterMax)
            } else {
                generationPowerKW = lossAdjustedKW
            }

            let forecastGenerationKWh = generationPowerKW * hours
            let loadEnergyKWh = loadKW * hours
            let avoidedGridImportKWh = min(max(forecastGenerationKWh, 0), loadEnergyKWh)
            let gridImportKWh = max(loadEnergyKWh - forecastGenerationKWh, 0)
            let pvCostSavingPence = avoidedGridImportKWh * rate.valueIncVAT
            let slotCostPence = gridImportKWh * rate.valueIncVAT
            let effectivePrice = loadEnergyKWh > 0 ? slotCostPence / loadEnergyKWh : rate.valueIncVAT

            return NetPriceHalfHour(
                validFrom: rate.validFrom,
                validTo: rate.validTo,
                agilePricePPerKWh: rate.valueIncVAT,
                loadEnergyKWh: loadEnergyKWh,
                forecastGenerationKWh: forecastGenerationKWh,
                avoidedGridImportKWh: avoidedGridImportKWh,
                gridImportKWh: gridImportKWh,
                pvCostSavingPence: pvCostSavingPence,
                slotCostPence: slotCostPence,
                effectivePricePPerKWh: effectivePrice
            )
        }
    }

    private var selected: NetPriceHalfHour? {
        if let selectedID,
           let match = results.first(where: { $0.id == selectedID }) {
            return match
        }
        return results.first
    }

    private var lowest: NetPriceHalfHour? {
        results.min(by: { $0.effectivePricePPerKWh < $1.effectivePricePPerKWh })
    }

    private var highest: NetPriceHalfHour? {
        results.max(by: { $0.effectivePricePPerKWh < $1.effectivePricePPerKWh })
    }

    private var averageEffectivePrice: Double? {
        guard !results.isEmpty else { return nil }
        return results.map(\.effectivePricePPerKWh).reduce(0, +) / Double(results.count)
    }

    var body: some View {
        VStack(spacing: 12) {
            header

            if settings.effectiveOptimiserLoadKW == nil {
                emptyState(
                    icon: "bolt.badge.clock",
                    title: "Set the optimiser load",
                    message: "Enter the controllable load power in App Settings. The historic nightly email used 3.0 kW."
                )
            } else if settings.effectivePeakPowerKWp == nil {
                emptyState(
                    icon: "sun.max.trianglebadge.exclamationmark",
                    title: "Add PV array capacity",
                    message: "Enter rated array kWp, or panel count and panel wattage, in App Settings."
                )
            } else if agileModel.rates.isEmpty {
                emptyState(
                    icon: "bolt.trianglebadge.exclamationmark",
                    title: "No Agile prices",
                    message: agileModel.errorMessage ?? "No Agile rates are loaded for this day."
                )
            } else if solarModel.forecast.isEmpty {
                emptyState(
                    icon: "sun.haze",
                    title: "No solar forecast",
                    message: solarModel.errorMessage ?? "A solar forecast is required for the selected day."
                )
            } else if !results.isEmpty {
                NetPriceWheelView(results: results, selectedID: $selectedID)
                    .frame(maxWidth: 560)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    resultTile(
                        title: "Best net price",
                        value: lowest.map { String(format: "%.2f p/kWh", $0.effectivePricePPerKWh) },
                        subtitle: lowest.map { timeRange($0) }
                    )
                    resultTile(
                        title: "Highest net price",
                        value: highest.map { String(format: "%.2f p/kWh", $0.effectivePricePPerKWh) },
                        subtitle: highest.map { timeRange($0) }
                    )
                    resultTile(
                        title: "Average net price",
                        value: averageEffectivePrice.map { String(format: "%.2f p/kWh", $0) },
                        subtitle: "Across matched half-hours"
                    )
                    resultTile(
                        title: "Optimiser load",
                        value: settings.effectiveOptimiserLoadKW.map { String(format: "%.2f kW", $0) },
                        subtitle: selected.map { String(format: "%.3f kWh in selected slot", $0.loadEnergyKWh) }
                    )
                }

                if let selected {
                    selectedBreakdown(selected)
                }

                modelExplanation
            } else {
                emptyState(
                    icon: "arrow.triangle.branch",
                    title: "No matching half-hours",
                    message: "Agile prices and the solar forecast could not be aligned for this selected day."
                )
            }
        }
        .onAppear { chooseInitialSelection() }
        .onChange(of: agileModel.rates) { _, _ in chooseInitialSelection() }
        .onChange(of: solarModel.forecast) { _, _ in chooseInitialSelection() }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Net electricity price")
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundStyle(accent)
                Text("Agile price after forecast PV offsets the configured load")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.65))
            }
            Spacer()
            Image(systemName: "bolt.circle.fill")
                .font(.title2)
                .foregroundStyle(.green)
        }
    }

    private func selectedBreakdown(_ item: NetPriceHalfHour) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Selected half-hour")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(accent)

            breakdownRow("Time", timeRange(item))
            breakdownRow("Published Agile price", String(format: "%.2f p/kWh", item.agilePricePPerKWh))
            breakdownRow("Configured load energy", String(format: "%.3f kWh", item.loadEnergyKWh))
            breakdownRow("Forecast PV generation", String(format: "%.3f kWh", item.forecastGenerationKWh))
            breakdownRow("PV used against load", String(format: "%.3f kWh", item.avoidedGridImportKWh))
            breakdownRow("PV cost saving", String(format: "%.2f p", item.pvCostSavingPence))
            breakdownRow("Expected grid import", String(format: "%.3f kWh", item.gridImportKWh))
            breakdownRow("Expected slot cost", String(format: "%.2f p", item.slotCostPence))
            breakdownRow("Net / adjusted price", String(format: "%.2f p/kWh", item.effectivePricePPerKWh))
        }
        .padding(14)
        .background(card.opacity(0.80), in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(line.opacity(0.75), lineWidth: 1.1))
    }

    private func breakdownRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .foregroundStyle(.white.opacity(0.62))
            Spacer(minLength: 10)
            Text(value)
                .foregroundStyle(.green)
                .monospacedDigit()
                .multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
    }

    private var modelExplanation: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Same optimiser logic as the nightly email")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(accent)

            Text("Load energy = configured kW × period hours. Forecast PV is deducted first. Grid import = max(load energy − forecast PV, 0). Slot cost = grid import × Agile price. Net price = slot cost ÷ complete load energy.")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.72))

            Text("PV cost saving = min(forecast PV, load energy) × Agile price. This is avoided import cost only; surplus export income is not included. At negative Agile prices the saving can be negative because importing would have been financially beneficial.")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.58))
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(card.opacity(0.78), in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(line.opacity(0.75), lineWidth: 1.1))
    }

    private func resultTile(title: String, value: String?, subtitle: String?) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(accent.opacity(0.88))
            Text(value ?? "—")
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.green)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 10, design: .rounded))
                    .foregroundStyle(.white.opacity(0.66))
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 82, alignment: .leading)
        .padding(13)
        .background(card.opacity(0.92), in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(line.opacity(0.8), lineWidth: 1.2))
    }

    private func emptyState(icon: String, title: String, message: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 42))
                .foregroundStyle(accent)
            Text(title)
                .font(.title3.bold())
                .foregroundStyle(accent)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
            Button("Open App Settings", action: openSettings)
                .buttonStyle(.bordered)
                .tint(accent)
        }
        .frame(maxWidth: .infinity, minHeight: 360)
    }

    private func chooseInitialSelection() {
        guard !results.isEmpty else {
            selectedID = nil
            return
        }
        if let selectedID, results.contains(where: { $0.id == selectedID }) { return }
        let now = Date()
        selectedID = results.first(where: { $0.validFrom <= now && now < $0.validTo })?.id ?? results.first?.id
    }

    private func timeRange(_ item: NetPriceHalfHour) -> String {
        "\(time(item.validFrom))–\(time(item.validTo))"
    }

    private func time(_ date: Date) -> String {
        date.formatted(.dateTime.hour().minute().timeZone(.omitted))
    }
}

struct NetPriceWheelView: View {
    let results: [NetPriceHalfHour]
    @Binding var selectedID: Date?

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            let center = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)
            let outerRadius = size * 0.46
            let innerRadius = size * 0.27

            ZStack {
                Canvas { context, _ in
                    guard !results.isEmpty else { return }
                    let step = 360.0 / Double(results.count)
                    for index in results.indices {
                        let start = Angle.degrees(-90 + Double(index) * step + 0.5)
                        let end = Angle.degrees(-90 + Double(index + 1) * step - 0.5)
                        var path = Path()
                        path.addArc(center: center, radius: outerRadius, startAngle: start, endAngle: end, clockwise: false)
                        path.addArc(center: center, radius: innerRadius, startAngle: end, endAngle: start, clockwise: true)
                        path.closeSubpath()
                        context.fill(path, with: .color(colour(for: results[index].effectivePricePPerKWh)))
                    }
                }

                if let index = results.firstIndex(where: { $0.id == selectedID }) {
                    NetPriceSectorOutline(index: index, count: results.count, innerRatio: innerRadius / outerRadius)
                        .stroke(.white, style: StrokeStyle(lineWidth: 2.5, lineJoin: .round))
                        .frame(width: outerRadius * 2, height: outerRadius * 2)
                        .position(center)
                        .allowsHitTesting(false)
                }

                if let selected = results.first(where: { $0.id == selectedID }) ?? results.first {
                    VStack(spacing: 2) {
                        Text("Net price")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.orange.opacity(0.88))
                        Text(String(format: "%.2f", selected.effectivePricePPerKWh))
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(colour(for: selected.effectivePricePPerKWh))
                        Text("p/kWh")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.72))
                        Text(String(format: "PV saving %.2f p", selected.pvCostSavingPence))
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(selected.pvCostSavingPence < 0 ? .red : .green)
                            .monospacedDigit()
                        Text("\(time(selected.validFrom))–\(time(selected.validTo))")
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundStyle(.orange.opacity(0.82))
                    }
                    .position(center)
                }

                clockLabels(center: center, radius: outerRadius)
                    .allowsHitTesting(false)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        select(at: value.location, center: center, outerRadius: outerRadius)
                    }
            )
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Net effective electricity price wheel")
            .accessibilityValue(accessibilityValue)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    @ViewBuilder
    private func clockLabels(center: CGPoint, radius: CGFloat) -> some View {
        ZStack {
            ForEach(Array(results.enumerated()), id: \.element.id) { index, item in
                let hour = Calendar.uk.component(.hour, from: item.validFrom)
                let minute = Calendar.uk.component(.minute, from: item.validFrom)
                if minute == 0 && hour.isMultiple(of: 6) {
                    let step = 360.0 / Double(max(results.count, 1))
                    let angle = (-90 + (Double(index) + 0.5) * step) * .pi / 180
                    Text(String(format: "%02d:00", hour))
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.75))
                        .position(
                            x: center.x + cos(angle) * radius * 0.86,
                            y: center.y + sin(angle) * radius * 0.86
                        )
                }
            }
        }
    }

    private func colour(for value: Double) -> Color {
        switch value {
        case ..<0:
            return Color(red: 0.086, green: 0.396, blue: 0.204)
        case 0..<5:
            return Color(red: 0.133, green: 0.773, blue: 0.369)
        case 5..<10:
            return Color(red: 0.518, green: 0.800, blue: 0.086)
        case 10..<20:
            return Color(red: 0.745, green: 0.949, blue: 0.392)
        case 20..<30:
            return Color(red: 0.992, green: 0.878, blue: 0.278)
        case 30..<40:
            return Color(red: 0.984, green: 0.573, blue: 0.235)
        case 40..<50:
            return Color(red: 0.937, green: 0.267, blue: 0.267)
        default:
            return Color(red: 0.600, green: 0.106, blue: 0.106)
        }
    }

    private func select(at point: CGPoint, center: CGPoint, outerRadius: CGFloat) {
        guard !results.isEmpty else { return }
        let dx = point.x - center.x
        let dy = point.y - center.y
        guard hypot(dx, dy) <= outerRadius else { return }

        var degrees = atan2(dy, dx) * 180 / .pi + 90
        if degrees < 0 { degrees += 360 }
        let index = min(Int(degrees / (360 / Double(results.count))), results.count - 1)
        selectedID = results[index].id
    }

    private var accessibilityValue: String {
        guard let selected = results.first(where: { $0.id == selectedID }) ?? results.first else {
            return "No net price selected"
        }
        return "\(time(selected.validFrom)) to \(time(selected.validTo)), \(String(format: "%.2f", selected.effectivePricePPerKWh)) pence per kilowatt hour, PV saving \(String(format: "%.2f", selected.pvCostSavingPence)) pence"
    }

    private func time(_ date: Date) -> String {
        date.formatted(.dateTime.hour().minute().timeZone(.omitted))
    }
}

private struct NetPriceSectorOutline: Shape {
    let index: Int
    let count: Int
    let innerRatio: CGFloat

    func path(in rect: CGRect) -> Path {
        guard count > 0 else { return Path() }
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outer = min(rect.width, rect.height) / 2
        let inner = outer * innerRatio
        let step = 360.0 / Double(count)
        let start = Angle.degrees(-90 + Double(index) * step + 0.5)
        let end = Angle.degrees(-90 + Double(index + 1) * step - 0.5)

        var path = Path()
        path.addArc(center: center, radius: outer, startAngle: start, endAngle: end, clockwise: false)
        path.addArc(center: center, radius: inner, startAngle: end, endAngle: start, clockwise: true)
        path.closeSubpath()
        return path
    }
}
