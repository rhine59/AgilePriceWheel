import SwiftUI

struct SolarForecastView: View {
    @ObservedObject var model: SolarForecastModel
    let selectedDate: Date
    let openSettings: () -> Void

    private let accent = Color.orange
    private let card = Color(red: 0.02, green: 0.13, blue: 0.21)
    private let line = Color(red: 0.06, green: 0.30, blue: 0.43)

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Solar irradiance forecast")
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundStyle(accent)
                    if let site = model.site {
                        Text(site.name)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.65))
                            .lineLimit(1)
                    }
                }
                Spacer()
                Image(systemName: "sun.max.fill")
                    .font(.title2)
                    .foregroundStyle(.yellow)
            }

            solarSourceStatus

            if model.site == nil {
                VStack(spacing: 14) {
                    Image(systemName: "location.circle")
                        .font(.system(size: 42))
                        .foregroundStyle(accent)
                    Text("Set the solar site")
                        .font(.title3.bold())
                        .foregroundStyle(accent)
                    Text("Choose the site in Settings using Current Location, place/postcode search, or manual latitude and longitude.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                    Button("Open Settings", action: openSettings)
                        .buttonStyle(.bordered)
                        .tint(accent)
                }
                .frame(maxWidth: .infinity, minHeight: 360)
            } else if model.isLoading && model.forecast.isEmpty {
                ProgressView("Loading solar forecast…")
                    .tint(accent)
                    .foregroundStyle(accent)
                    .frame(maxWidth: .infinity, minHeight: 360)
            } else if !model.forecast.isEmpty {
                SolarWheelView(
                    forecast: model.forecast,
                    selectedSolarID: $model.selectedSolarID
                )
                .frame(maxWidth: 560)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    solarTile(title: "Peak irradiance", value: model.maximumIrradiance, subtitle: peakTime)
                    solarTile(title: "Daylight average", value: model.daylightAverage, subtitle: "W/m²")
                    selectedTile
                    siteTile
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "sun.haze")
                        .font(.system(size: 40))
                        .foregroundStyle(accent)
                    Text(model.errorMessage ?? "No solar forecast available")
                        .foregroundStyle(.white.opacity(0.72))
                        .multilineTextAlignment(.center)
                    Button("Refresh solar forecast") {
                        Task { await model.refresh(for: selectedDate) }
                    }
                    .buttonStyle(.bordered)
                    .tint(accent)
                }
                .frame(maxWidth: .infinity, minHeight: 340)
            }

            HStack(spacing: 8) {
                Image(systemName: "arrow.left.and.right")
                Text("Swipe right for prices · swipe left for PV Forecast")
            }
            .font(.caption)
            .foregroundStyle(.white.opacity(0.5))
        }
    }

    private var solarSourceStatus: some View {
        VStack(spacing: 2) {
            HStack(spacing: 6) {
                Image(systemName: sourceIcon)
                Text(model.dataSourceLabel)
                if model.isLoading {
                    ProgressView().controlSize(.mini).tint(sourceColour)
                }
            }
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundStyle(sourceColour)

            if let message = model.syncMessage, !message.isEmpty {
                Text(message)
                    .font(.system(size: 10, design: .rounded))
                    .foregroundStyle(.white.opacity(0.62))
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var sourceColour: Color {
        switch model.dataOrigin {
        case .none: return .secondary
        case .server: return .green
        case .localCache: return .orange
        }
    }

    private var sourceIcon: String {
        switch model.dataOrigin {
        case .none: return "questionmark.circle"
        case .server: return "network"
        case .localCache: return "internaldrive"
        }
    }

    private var selectedTile: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Selected half hour")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(accent.opacity(0.88))
            if let selected = model.selectedSolar {
                Text(String(format: "%.0f W/m²", selected.wattsPerSquareMetre))
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.yellow)
                Text("\(time(selected.validFrom))–\(time(selected.validTo))")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.66))
            } else {
                Text("—").foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 78, alignment: .leading)
        .padding(13)
        .background(card.opacity(0.92), in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(line.opacity(0.8), lineWidth: 1.2))
    }

    private var siteTile: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Forecast site")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(accent.opacity(0.88))
            if let site = model.site {
                Text(site.coordinateLabel)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.cyan)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Text("Latitude, longitude")
                    .font(.system(size: 10, design: .rounded))
                    .foregroundStyle(.white.opacity(0.66))
            }
        }
        .frame(maxWidth: .infinity, minHeight: 78, alignment: .leading)
        .padding(13)
        .background(card.opacity(0.92), in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(line.opacity(0.8), lineWidth: 1.2))
    }

    private func solarTile(title: String, value: Double?, subtitle: String?) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(accent.opacity(0.88))
            if let value {
                Text(String(format: "%.0f W/m²", value))
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.yellow)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 10, design: .rounded))
                        .foregroundStyle(.white.opacity(0.66))
                }
            } else {
                Text("—").foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 78, alignment: .leading)
        .padding(13)
        .background(card.opacity(0.92), in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(line.opacity(0.8), lineWidth: 1.2))
    }

    private var peakTime: String? {
        guard let maxValue = model.maximumIrradiance,
              let item = model.forecast.first(where: { $0.wattsPerSquareMetre == maxValue }) else { return nil }
        return "\(time(item.validFrom))–\(time(item.validTo))"
    }

    private func time(_ date: Date) -> String {
        date.formatted(.dateTime.hour().minute().timeZone(.omitted))
    }
}

struct SolarWheelView: View {
    let forecast: [SolarHalfHour]
    @Binding var selectedSolarID: Date?

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            let center = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)
            let outerRadius = size * 0.46
            let innerRadius = size * 0.27

            ZStack {
                Canvas { context, _ in
                    guard !forecast.isEmpty else { return }
                    let step = 360.0 / Double(forecast.count)
                    let maxValue = max(forecast.map(\.wattsPerSquareMetre).max() ?? 1, 1)

                    for index in forecast.indices {
                        let start = Angle.degrees(-90 + Double(index) * step + 0.5)
                        let end = Angle.degrees(-90 + Double(index + 1) * step - 0.5)
                        var path = Path()
                        path.addArc(center: center, radius: outerRadius, startAngle: start, endAngle: end, clockwise: false)
                        path.addArc(center: center, radius: innerRadius, startAngle: end, endAngle: start, clockwise: true)
                        path.closeSubpath()

                        let value = forecast[index].wattsPerSquareMetre
                        context.fill(path, with: .color(solarColour(value: value, maximum: maxValue)))
                    }
                }

                if let index = forecast.firstIndex(where: { $0.id == selectedSolarID }) {
                    SolarSectorOutline(index: index, count: forecast.count, innerRatio: innerRadius / outerRadius)
                        .stroke(.white, style: StrokeStyle(lineWidth: 2.5, lineJoin: .round))
                        .frame(width: outerRadius * 2, height: outerRadius * 2)
                        .position(center)
                        .allowsHitTesting(false)
                }

                if let selected = forecast.first(where: { $0.id == selectedSolarID }) {
                    VStack(spacing: 2) {
                        Text("Solar forecast")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.orange.opacity(0.88))
                        Text(String(format: "%.0f", selected.wattsPerSquareMetre))
                            .font(.system(size: 42, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.yellow)
                        Text("W/m²")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.7))
                        Text("\(time(selected.validFrom))–\(time(selected.validTo))")
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundStyle(.orange.opacity(0.82))
                    }
                    .position(center)
                }

                solarClockLabels(center: center, radius: outerRadius)
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
            .accessibilityLabel("Half-hour solar irradiance forecast wheel")
            .accessibilityValue(accessibilityValue)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    @ViewBuilder
    private func solarClockLabels(center: CGPoint, radius: CGFloat) -> some View {
        ZStack {
            ForEach(Array(forecast.enumerated()), id: \.element.id) { index, item in
                let hour = Calendar.uk.component(.hour, from: item.validFrom)
                let minute = Calendar.uk.component(.minute, from: item.validFrom)
                if minute == 0 && hour.isMultiple(of: 6) {
                    let step = 360.0 / Double(max(forecast.count, 1))
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

    private func solarColour(value: Double, maximum: Double) -> Color {
        if value <= 0.5 {
            return Color(red: 0.03, green: 0.12, blue: 0.20)
        }
        let t = min(max(value / maximum, 0), 1)
        return Color(hue: 0.14 - (0.04 * t), saturation: 0.72 + (0.20 * t), brightness: 0.45 + (0.55 * t))
    }

    private func select(at point: CGPoint, center: CGPoint, outerRadius: CGFloat) {
        guard !forecast.isEmpty else { return }
        let dx = point.x - center.x
        let dy = point.y - center.y
        guard hypot(dx, dy) <= outerRadius else { return }

        var degrees = atan2(dy, dx) * 180 / .pi + 90
        if degrees < 0 { degrees += 360 }
        let index = min(Int(degrees / (360 / Double(forecast.count))), forecast.count - 1)
        selectedSolarID = forecast[index].id
    }

    private var accessibilityValue: String {
        guard let selected = forecast.first(where: { $0.id == selectedSolarID }) else { return "No selected solar period" }
        return "\(time(selected.validFrom)) to \(time(selected.validTo)), \(Int(selected.wattsPerSquareMetre.rounded())) watts per square metre"
    }

    private func time(_ date: Date) -> String {
        date.formatted(.dateTime.hour().minute().timeZone(.omitted))
    }
}

private struct SolarSectorOutline: Shape {
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
