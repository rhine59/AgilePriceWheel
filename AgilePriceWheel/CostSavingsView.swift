import SwiftUI

struct CostSavingHalfHour: Identifiable, Hashable {
    let validFrom: Date
    let validTo: Date
    let agilePricePPerKWh: Double
    let loadEnergyKWh: Double
    let forecastGenerationKWh: Double
    let avoidedGridImportKWh: Double
    let savingPence: Double

    var id: Date { validFrom }
}

struct CostSavingsView: View {
    @ObservedObject var agileModel: AgileViewModel
    @ObservedObject var solarModel: SolarForecastModel
    @ObservedObject var settings: AppSettingsStore
    let openSettings: () -> Void

    @State private var selectedID: Date?

    private let accent = Color.orange
    private let card = Color(red: 0.02, green: 0.13, blue: 0.21)
    private let line = Color(red: 0.06, green: 0.30, blue: 0.43)

    private var results: [CostSavingHalfHour] {
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
            let savingPence = avoidedGridImportKWh * rate.valueIncVAT

            return CostSavingHalfHour(
                validFrom: rate.validFrom,
                validTo: rate.validTo,
                agilePricePPerKWh: rate.valueIncVAT,
                loadEnergyKWh: loadEnergyKWh,
                forecastGenerationKWh: forecastGenerationKWh,
                avoidedGridImportKWh: avoidedGridImportKWh,
                savingPence: savingPence
            )
        }
    }

    private var selected: CostSavingHalfHour? {
        if let selectedID,
           let match = results.first(where: { $0.id == selectedID }) {
            return match
        }
        return results.first
    }

    private var totalSavingPence: Double? {
        guard !results.isEmpty else { return nil }
        return results.reduce(0) { $0 + $1.savingPence }
    }

    private var bestSaving: CostSavingHalfHour? {
        results.max(by: { $0.savingPence < $1.savingPence })
    }

    private var totalAvoidedImportKWh: Double? {
        guard !results.isEmpty else { return nil }
        return results.reduce(0) { $0 + $1.avoidedGridImportKWh }
    }

    var body: some View {
        VStack(spacing: 12) {
            header

            if settings.effectiveOptimiserLoadKW == nil {
                emptyState(
                    icon: "bolt.badge.clock",
                    title: "Set the optimiser load",
                    message: "Enter the controllable load power in App Settings before PV cost savings can be estimated."
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
                CostSavingsWheelView(results: results, selectedID: $selectedID)
                    .frame(maxWidth: 560)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    savingTile(
                        title: "Forecast day saving",
                        value: totalSavingPence.map { moneyFromPence($0) },
                        subtitle: "Avoided Agile import cost"
                    )
                    savingTile(
                        title: "Best half-hour",
                        value: bestSaving.map { String(format: "%.2f p", $0.savingPence) },
                        subtitle: bestSaving.map { timeRange($0) }
                    )
                    savingTile(
                        title: "Avoided grid import",
                        value: totalAvoidedImportKWh.map { String(format: "%.3f kWh", $0) },
                        subtitle: "Across the selected day"
                    )
                    savingTile(
                        title: "Selected saving",
                        value: selected.map { String(format: "%.2f p", $0.savingPence) },
                        subtitle: selected.map { timeRange($0) }
                    )
                }

                if let selected {
                    selectedBreakdown(selected)
                }

                explanation
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
                Text("PV cost savings")
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundStyle(accent)
                Text("Avoided grid-import cost from forecast PV")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.65))
            }
            Spacer()
            Image(systemName: "banknote.fill")
                .font(.title2)
                .foregroundStyle(.green)
        }
    }

    private func selectedBreakdown(_ item: CostSavingHalfHour) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Selected half-hour")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(accent)

            breakdownRow("Time", timeRange(item))
            breakdownRow("Published Agile price", String(format: "%.2f p/kWh", item.agilePricePPerKWh))
            breakdownRow("Configured load energy", String(format: "%.3f kWh", item.loadEnergyKWh))
            breakdownRow("Forecast PV generation", String(format: "%.3f kWh", item.forecastGenerationKWh))
            breakdownRow("PV used against load", String(format: "%.3f kWh", item.avoidedGridImportKWh))
            breakdownRow("PV cost saving", String(format: "%.2f p", item.savingPence))
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

    private var explanation: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("How the saving is calculated")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(accent)

            Text("Avoided import = min(forecast PV energy, configured load energy). PV cost saving = avoided import × published Agile price for that half-hour.")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.72))

            Text("Only PV that can offset the configured load is counted. Surplus PV export income is not included. If the Agile price is negative, the displayed saving can also be negative because using PV instead of importing would forgo the benefit of being paid to consume electricity.")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.58))
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(card.opacity(0.78), in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(line.opacity(0.75), lineWidth: 1.1))
    }

    private func savingTile(title: String, value: String?, subtitle: String?) -> some View {
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

    private func moneyFromPence(_ pence: Double) -> String {
        if abs(pence) < 100 {
            return String(format: "%.2f p", pence)
        }
        return String(format: "£%.2f", pence / 100.0)
    }

    private func timeRange(_ item: CostSavingHalfHour) -> String {
        "\(time(item.validFrom))–\(time(item.validTo))"
    }

    private func time(_ date: Date) -> String {
        date.formatted(.dateTime.hour().minute().timeZone(.omitted))
    }
}

struct CostSavingsWheelView: View {
    let results: [CostSavingHalfHour]
    @Binding var selectedID: Date?

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            let center = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)
            let outerRadius = size * 0.46
            let innerRadius = size * 0.27
            let positiveMaximum = max(results.map(\.savingPence).filter { $0 > 0 }.max() ?? 0.01, 0.01)
            let negativeMagnitude = max(abs(results.map(\.savingPence).filter { $0 < 0 }.min() ?? -0.01), 0.01)

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
                        context.fill(
                            path,
                            with: .color(colour(for: results[index].savingPence, positiveMaximum: positiveMaximum, negativeMagnitude: negativeMagnitude))
                        )
                    }
                }

                if let index = results.firstIndex(where: { $0.id == selectedID }) {
                    CostSavingSectorOutline(index: index, count: results.count, innerRatio: innerRadius / outerRadius)
                        .stroke(.white, style: StrokeStyle(lineWidth: 2.5, lineJoin: .round))
                        .frame(width: outerRadius * 2, height: outerRadius * 2)
                        .position(center)
                        .allowsHitTesting(false)
                }

                if let selected = results.first(where: { $0.id == selectedID }) ?? results.first {
                    VStack(spacing: 2) {
                        Text("PV saving")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.orange.opacity(0.88))
                        Text(String(format: "%.2f", selected.savingPence))
                            .font(.system(size: 39, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(selected.savingPence < 0 ? .red : .green)
                        Text("p / half-hour")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.72))
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
            .accessibilityLabel("Half-hour PV cost savings wheel")
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

    private func colour(for value: Double, positiveMaximum: Double, negativeMagnitude: Double) -> Color {
        if value < 0 {
            let t = min(abs(value) / negativeMagnitude, 1)
            return Color(hue: 0.0, saturation: 0.55 + 0.35 * t, brightness: 0.45 + 0.35 * t)
        }
        if value < 0.001 {
            return Color(red: 0.03, green: 0.12, blue: 0.20)
        }
        let t = min(value / positiveMaximum, 1)
        return Color(hue: 0.36, saturation: 0.48 + 0.42 * t, brightness: 0.35 + 0.55 * t)
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
            return "No PV cost saving selected"
        }
        return "\(time(selected.validFrom)) to \(time(selected.validTo)), \(String(format: "%.2f", selected.savingPence)) pence saving"
    }

    private func time(_ date: Date) -> String {
        date.formatted(.dateTime.hour().minute().timeZone(.omitted))
    }
}

private struct CostSavingSectorOutline: Shape {
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
