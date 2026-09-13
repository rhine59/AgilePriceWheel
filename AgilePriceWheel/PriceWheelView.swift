import SwiftUI

struct PriceWheelView: View {
    let rates: [HalfHourRate]
    @Binding var selectedRateID: Date?

    private var scale: PriceColourScale { PriceColourScale(rates: rates) }

    private var selectedRate: HalfHourRate? {
        guard let selectedRateID else { return nil }
        return rates.first { $0.id == selectedRateID }
    }

    private var isCurrentSelection: Bool {
        guard let selectedRate else { return false }
        let now = Date()
        return selectedRate.validFrom <= now && now < selectedRate.validTo
    }

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            let center = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)
            let outerRadius = size * 0.405
            let innerRadius = size * 0.285
            let labelRadius = size * 0.468

            ZStack {
                // Subtle outer guide ring.
                Circle()
                    .stroke(Color.cyan.opacity(0.22), lineWidth: 2)
                    .frame(width: outerRadius * 2.16, height: outerRadius * 2.16)
                    .position(center)

                Canvas { context, _ in
                    guard !rates.isEmpty else { return }
                    let step = 360.0 / Double(rates.count)

                    for index in rates.indices {
                        let gap = min(0.7, step * 0.10)
                        let start = Angle.degrees(-90 + Double(index) * step + gap)
                        let end = Angle.degrees(-90 + Double(index + 1) * step - gap)
                        let path = annularSector(
                            center: center,
                            innerRadius: innerRadius,
                            outerRadius: outerRadius,
                            start: start,
                            end: end
                        )

                        context.fill(path, with: .color(scale.colour(for: rates[index].valueIncVAT)))
                        context.stroke(path, with: .color(Color.black.opacity(0.72)), lineWidth: 1.4)
                    }

                    // White clock ticks every three hours.
                    for (index, rate) in rates.enumerated() {
                        let hour = Calendar.uk.component(.hour, from: rate.validFrom)
                        let minute = Calendar.uk.component(.minute, from: rate.validFrom)
                        guard minute == 0, hour.isMultiple(of: 3) else { continue }

                        let angle = (-90 + Double(index) * step) * .pi / 180
                        let innerTick = hour.isMultiple(of: 6) ? outerRadius * 1.045 : outerRadius * 1.06
                        let outerTick = hour.isMultiple(of: 6) ? outerRadius * 1.16 : outerRadius * 1.12
                        let p1 = CGPoint(
                            x: center.x + cos(angle) * innerTick,
                            y: center.y + sin(angle) * innerTick
                        )
                        let p2 = CGPoint(
                            x: center.x + cos(angle) * outerTick,
                            y: center.y + sin(angle) * outerTick
                        )

                        var tick = Path()
                        tick.move(to: p1)
                        tick.addLine(to: p2)
                        context.stroke(
                            tick,
                            with: .color(.white.opacity(0.92)),
                            style: StrokeStyle(
                                lineWidth: hour.isMultiple(of: 6) ? 4 : 2.5,
                                lineCap: .round
                            )
                        )
                    }
                }

                if let selectedIndex = rates.firstIndex(where: { $0.id == selectedRateID }) {
                    AnnularSectorShape(
                        index: selectedIndex,
                        count: rates.count,
                        innerRatio: innerRadius / outerRadius
                    )
                    .stroke(.white, style: StrokeStyle(lineWidth: 4, lineJoin: .round))
                    .frame(width: outerRadius * 2, height: outerRadius * 2)
                    .position(center)
                    .shadow(color: .white.opacity(0.35), radius: 3)
                    .allowsHitTesting(false)
                }

                // Dark inner face.
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color(red: 0.035, green: 0.12, blue: 0.20), Color(red: 0.01, green: 0.07, blue: 0.12)],
                            center: .center,
                            startRadius: 0,
                            endRadius: innerRadius
                        )
                    )
                    .overlay(
                        Circle().stroke(Color.cyan.opacity(0.35), lineWidth: 2)
                    )
                    .frame(width: innerRadius * 1.94, height: innerRadius * 1.94)
                    .position(center)
                    .allowsHitTesting(false)

                centerReadout
                    .frame(width: innerRadius * 1.65)
                    .position(center)
                    .allowsHitTesting(false)

                CardinalLabels(center: center, radius: labelRadius)
                    .allowsHitTesting(false)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        select(at: value.location, center: center, innerRadius: innerRadius, outerRadius: outerRadius)
                    }
            )
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Agile half-hour price wheel")
            .accessibilityValue(accessibilityValue)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    @ViewBuilder
    private var centerReadout: some View {
        if let selectedRate {
            VStack(spacing: 3) {
                Text(isCurrentSelection ? "Current price" : "Selected price")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.orange.opacity(0.95))

                Text(selectedRate.valueIncVAT, format: .number.precision(.fractionLength(1)))
                    .font(.system(size: 48, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.orange)
                    .minimumScaleFactor(0.7)

                Text("p/kWh")
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .foregroundStyle(.orange)

                Text("\(time(selectedRate.validFrom))–\(time(selectedRate.validTo))")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.orange.opacity(0.82))
                    .monospacedDigit()
                    .lineLimit(1)
            }
        } else {
            Text("Touch a sector")
                .font(.headline)
                .foregroundStyle(.orange)
        }
    }

    private func annularSector(
        center: CGPoint,
        innerRadius: CGFloat,
        outerRadius: CGFloat,
        start: Angle,
        end: Angle
    ) -> Path {
        var path = Path()
        path.addArc(center: center, radius: outerRadius, startAngle: start, endAngle: end, clockwise: false)
        path.addArc(center: center, radius: innerRadius, startAngle: end, endAngle: start, clockwise: true)
        path.closeSubpath()
        return path
    }

    private func select(at point: CGPoint, center: CGPoint, innerRadius: CGFloat, outerRadius: CGFloat) {
        guard !rates.isEmpty else { return }

        let dx = point.x - center.x
        let dy = point.y - center.y
        let distance = hypot(dx, dy)
        guard distance >= innerRadius * 0.82, distance <= outerRadius * 1.18 else { return }

        var degrees = atan2(dy, dx) * 180 / .pi + 90
        if degrees < 0 { degrees += 360 }

        let index = min(Int(degrees / (360 / Double(rates.count))), rates.count - 1)
        selectedRateID = rates[index].id
    }

    private func time(_ date: Date) -> String {
        date.formatted(.dateTime.hour().minute().timeZone(.omitted))
    }

    private var accessibilityValue: String {
        guard let selectedRate else { return "No selected price" }
        return "\(selectedRate.validFrom.formatted(date: .omitted, time: .shortened)) to \(selectedRate.validTo.formatted(date: .omitted, time: .shortened)), \(selectedRate.valueIncVAT.formatted(.number.precision(.fractionLength(2)))) pence per kilowatt hour"
    }
}

private struct AnnularSectorShape: Shape {
    let index: Int
    let count: Int
    let innerRatio: CGFloat

    func path(in rect: CGRect) -> Path {
        guard count > 0 else { return Path() }

        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outerRadius = min(rect.width, rect.height) / 2
        let innerRadius = outerRadius * innerRatio
        let step = 360.0 / Double(count)
        let gap = min(0.7, step * 0.10)
        let start = Angle.degrees(-90 + Double(index) * step + gap)
        let end = Angle.degrees(-90 + Double(index + 1) * step - gap)

        var path = Path()
        path.addArc(center: center, radius: outerRadius, startAngle: start, endAngle: end, clockwise: false)
        path.addArc(center: center, radius: innerRadius, startAngle: end, endAngle: start, clockwise: true)
        path.closeSubpath()
        return path
    }
}

private struct CardinalLabels: View {
    let center: CGPoint
    let radius: CGFloat

    private let labels: [(String, Double)] = [
        ("00:00", -90),
        ("06:00", 180),
        ("12:00", 90),
        ("18:00", 0)
    ]

    var body: some View {
        ZStack {
            ForEach(labels, id: \.0) { label, degrees in
                let angle = degrees * .pi / 180
                Text(label)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(.orange)
                    .position(
                        x: center.x + cos(angle) * radius,
                        y: center.y + sin(angle) * radius
                    )
            }
        }
    }
}
