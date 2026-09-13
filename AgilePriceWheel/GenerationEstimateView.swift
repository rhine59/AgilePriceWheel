import SwiftUI

struct GenerationHalfHour: Identifiable, Hashable {
    let validFrom: Date
    let validTo: Date
    let irradianceWm2: Double
    let estimatedPowerKW: Double
    let estimatedEnergyKWh: Double

    var id: Date { validFrom }
}

struct GenerationEstimateView: View {
    @ObservedObject var solarModel: SolarForecastModel
    @ObservedObject var settings: AppSettingsStore
    let selectedDate: Date
    let openSettings: () -> Void

    @State private var selectedID: Date?

    private let accent = Color.orange
    private let card = Color(red: 0.02, green: 0.13, blue: 0.21)
    private let line = Color(red: 0.06, green: 0.30, blue: 0.43)

    private var estimates: [GenerationHalfHour] {
        guard let peakKWp = settings.effectivePeakPowerKWp, peakKWp > 0 else { return [] }

        return solarModel.forecast.map { item in
            let irradianceFactor = max(item.wattsPerSquareMetre, 0) / 1000.0
            let rawPowerKW = peakKWp * irradianceFactor
            let lossAdjustedKW = rawPowerKW * settings.generationLossFactor
            let clippedKW: Double
            if let inverterMax = settings.effectiveInverterMaxKW {
                clippedKW = min(lossAdjustedKW, inverterMax)
            } else {
                clippedKW = lossAdjustedKW
            }

            let hours = max(item.validTo.timeIntervalSince(item.validFrom) / 3600.0, 0)
            return GenerationHalfHour(
                validFrom: item.validFrom,
                validTo: item.validTo,
                irradianceWm2: item.wattsPerSquareMetre,
                estimatedPowerKW: clippedKW,
                estimatedEnergyKWh: clippedKW * hours
            )
        }
    }

    private var selectedEstimate: GenerationHalfHour? {
        if let selectedID,
           let exact = estimates.first(where: { $0.id == selectedID }) {
            return exact
        }
        return estimates.first
    }

    private var totalEnergyKWh: Double? {
        guard !estimates.isEmpty else { return nil }
        return estimates.reduce(0) { $0 + $1.estimatedEnergyKWh }
    }

    private var peakPowerKW: Double? {
        estimates.map(\.estimatedPowerKW).max()
    }

    var body: some View {
        VStack(spacing: 12) {
            header

            if solarModel.site == nil {
                emptyState(
                    icon: "location.circle",
                    title: "Set the solar site",
                    message: "A solar forecast site is required before PV generation can be estimated."
                )
            } else if settings.effectivePeakPowerKWp == nil {
                emptyState(
                    icon: "solar-panel",
                    title: "Add PV array capacity",
                    message: "Enter rated peak power in kWp, or panel count and panel wattage, in App Settings."
                )
            } else if solarModel.isLoading && solarModel.forecast.isEmpty {
                ProgressView("Loading solar forecast…")
                    .tint(accent)
                    .foregroundStyle(accent)
                    .frame(maxWidth: .infinity, minHeight: 360)
            } else if !estimates.isEmpty {
                GenerationWheelView(estimates: estimates, selectedID: $selectedID)
                    .frame(maxWidth: 560)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    generationTile(
                        title: "Estimated day total",
                        value: totalEnergyKWh.map { String(format: "%.2f kWh", $0) },
                        subtitle: "Sum of all half-hours"
                    )

                    generationTile(
                        title: "Peak output",
                        value: peakPowerKW.map { String(format: "%.2f kW", $0) },
                        subtitle: peakTime
                    )

                    generationTile(
                        title: "Selected half-hour",
                        value: selectedEstimate.map { String(format: "%.3f kWh", $0.estimatedEnergyKWh) },
                        subtitle: selectedEstimate.map { "\(time($0.validFrom))–\(time($0.validTo)) · \(String(format: "%.2f kW", $0.estimatedPowerKW))" }
                    )

                    generationTile(
                        title: "Array used",
                        value: settings.effectivePeakPowerKWp.map { String(format: "%.2f kWp", $0) },
                        subtitle: arraySubtitle
                    )
                }

                assumptionsCard
            } else {
                emptyState(
                    icon: "sun.max.trianglebadge.exclamationmark",
                    title: "No generation estimate",
                    message: solarModel.errorMessage ?? "No solar forecast is available for this day."
                )
            }

            HStack(spacing: 8) {
                Text("Swipe right for Solar Forecast")
                Image(systemName: "arrow.left.and.right")
                Text("left for App Settings")
            }
            .font(.caption2)
            .foregroundStyle(.white.opacity(0.5))
        }
        .onAppear { chooseInitialSelection() }
        .onChange(of: solarModel.forecast) { _, _ in chooseInitialSelection() }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("PV generation estimate")
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundStyle(accent)
                Text("Half-hour estimated electrical energy")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.65))
            }
            Spacer()
            Image(systemName: "bolt.sun.fill")
                .font(.title2)
                .foregroundStyle(.yellow)
        }
    }

    private var assumptionsCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Current estimate model")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(accent)

            Text("Estimated power = array kWp × (forecast GHI ÷ 1000) × (1 − system losses), then limited by the configured inverter maximum. Half-hour energy is estimated power × period duration.")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.72))

            Text("Tilt and azimuth are stored but are not yet applied because the current weather input is horizontal irradiance (GHI), not plane-of-array irradiance. Shading, panel temperature, snow and detailed inverter efficiency are also not modelled yet.")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.58))
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(card.opacity(0.78), in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(line.opacity(0.75), lineWidth: 1.1))
    }

    private func generationTile(title: String, value: String?, subtitle: String?) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(accent.opacity(0.88))

            Text(value ?? "—")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.green)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 10, design: .rounded))
                    .foregroundStyle(.white.opacity(0.66))
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)
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

    private var peakTime: String? {
        guard let peakPowerKW,
              let item = estimates.first(where: { $0.estimatedPowerKW == peakPowerKW }) else { return nil }
        return "\(time(item.validFrom))–\(time(item.validTo))"
    }

    private var arraySubtitle: String {
        var parts: [String] = []
        if !settings.arrayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            parts.append(settings.arrayName)
        }
        if let losses = settings.systemLossPercent {
            parts.append(String(format: "%.1f%% losses", losses))
        }
        if let inverter = settings.effectiveInverterMaxKW {
            parts.append(String(format: "%.2f kW inverter", inverter))
        }
        return parts.isEmpty ? "Configured PV capacity" : parts.joined(separator: " · ")
    }

    private func chooseInitialSelection() {
        guard !estimates.isEmpty else {
            selectedID = nil
            return
        }
        if let existing = selectedID, estimates.contains(where: { $0.id == existing }) { return }
        let now = Date()
        selectedID = estimates.first(where: { $0.validFrom <= now && now < $0.validTo })?.id ?? estimates.first?.id
    }

    private func time(_ date: Date) -> String {
        date.formatted(.dateTime.hour().minute().timeZone(.omitted))
    }
}

struct GenerationWheelView: View {
    let estimates: [GenerationHalfHour]
    @Binding var selectedID: Date?

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            let center = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)
            let outerRadius = size * 0.46
            let innerRadius = size * 0.27

            ZStack {
                Canvas { context, _ in
                    guard !estimates.isEmpty else { return }
                    let step = 360.0 / Double(estimates.count)
                    let maximum = max(estimates.map(\.estimatedEnergyKWh).max() ?? 0.001, 0.001)

                    for index in estimates.indices {
                        let start = Angle.degrees(-90 + Double(index) * step + 0.5)
                        let end = Angle.degrees(-90 + Double(index + 1) * step - 0.5)
                        var path = Path()
                        path.addArc(center: center, radius: outerRadius, startAngle: start, endAngle: end, clockwise: false)
                        path.addArc(center: center, radius: innerRadius, startAngle: end, endAngle: start, clockwise: true)
                        path.closeSubpath()
                        context.fill(path, with: .color(colour(for: estimates[index].estimatedEnergyKWh, maximum: maximum)))
                    }
                }

                if let index = estimates.firstIndex(where: { $0.id == selectedID }) {
                    GenerationSectorOutline(index: index, count: estimates.count, innerRatio: innerRadius / outerRadius)
                        .stroke(.white, style: StrokeStyle(lineWidth: 2.5, lineJoin: .round))
                        .frame(width: outerRadius * 2, height: outerRadius * 2)
                        .position(center)
                        .allowsHitTesting(false)
                }

                if let selected = estimates.first(where: { $0.id == selectedID }) ?? estimates.first {
                    VStack(spacing: 2) {
                        Text("Generation")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.orange.opacity(0.88))
                        Text(String(format: "%.3f", selected.estimatedEnergyKWh))
                            .font(.system(size: 38, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.green)
                        Text("kWh / half-hour")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.7))
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
            .accessibilityLabel("Half-hour PV generation estimate wheel")
            .accessibilityValue(accessibilityValue)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    @ViewBuilder
    private func clockLabels(center: CGPoint, radius: CGFloat) -> some View {
        ZStack {
            ForEach(Array(estimates.enumerated()), id: \.element.id) { index, item in
                let hour = Calendar.uk.component(.hour, from: item.validFrom)
                let minute = Calendar.uk.component(.minute, from: item.validFrom)
                if minute == 0 && hour.isMultiple(of: 6) {
                    let step = 360.0 / Double(max(estimates.count, 1))
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

    private func colour(for value: Double, maximum: Double) -> Color {
        if value <= 0.0005 { return Color(red: 0.03, green: 0.12, blue: 0.20) }
        let t = min(max(value / maximum, 0), 1)
        return Color(hue: 0.34 - 0.07 * t, saturation: 0.72 + 0.20 * t, brightness: 0.38 + 0.55 * t)
    }

    private func select(at point: CGPoint, center: CGPoint, outerRadius: CGFloat) {
        guard !estimates.isEmpty else { return }
        let dx = point.x - center.x
        let dy = point.y - center.y
        guard hypot(dx, dy) <= outerRadius else { return }

        var degrees = atan2(dy, dx) * 180 / .pi + 90
        if degrees < 0 { degrees += 360 }
        let index = min(Int(degrees / (360 / Double(estimates.count))), estimates.count - 1)
        selectedID = estimates[index].id
    }

    private var accessibilityValue: String {
        guard let selected = estimates.first(where: { $0.id == selectedID }) ?? estimates.first else {
            return "No generation estimate selected"
        }
        return "\(time(selected.validFrom)) to \(time(selected.validTo)), \(String(format: "%.3f", selected.estimatedEnergyKWh)) kilowatt hours"
    }

    private func time(_ date: Date) -> String {
        date.formatted(.dateTime.hour().minute().timeZone(.omitted))
    }
}

private struct GenerationSectorOutline: Shape {
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
