import SwiftUI

struct PriceWheelView: View {
    let rates: [HalfHourRate]
    @Binding var selectedRateID: Date?

    private var scale: PriceColourScale { PriceColourScale(rates: rates) }

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            let center = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)
            let radius = size * 0.47

            ZStack {
                Canvas { context, _ in
                    guard !rates.isEmpty else { return }
                    let step = 360.0 / Double(rates.count)

                    for index in rates.indices {
                        let start = Angle.degrees(-90 + Double(index) * step)
                        let end = Angle.degrees(-90 + Double(index + 1) * step)
                        var path = Path()
                        path.move(to: center)
                        path.addArc(center: center, radius: radius, startAngle: start, endAngle: end, clockwise: false)
                        path.closeSubpath()

                        context.fill(path, with: .color(scale.colour(for: rates[index].valueIncVAT)))
                        context.stroke(path, with: .color(.white.opacity(0.45)), lineWidth: 0.55)
                    }

                    // Hour marks around the rim. They remain meaningful on DST days because labels use actual local time.
                    for (index, rate) in rates.enumerated() {
                        let comps = Calendar.uk.dateComponents([.minute], from: rate.validFrom)
                        guard comps.minute == 0 else { continue }
                        let angle = (-90 + (Double(index) + 0.5) * step) * .pi / 180
                        let p1 = CGPoint(x: center.x + cos(angle) * radius * 0.91,
                                         y: center.y + sin(angle) * radius * 0.91)
                        let p2 = CGPoint(x: center.x + cos(angle) * radius,
                                         y: center.y + sin(angle) * radius)
                        var tick = Path()
                        tick.move(to: p1)
                        tick.addLine(to: p2)
                        context.stroke(tick, with: .color(.white.opacity(0.9)), lineWidth: 1.1)
                    }
                }

                if let selectedIndex = rates.firstIndex(where: { $0.id == selectedRateID }) {
                    SectorOutline(index: selectedIndex, count: rates.count)
                        .stroke(.primary, style: StrokeStyle(lineWidth: 3, lineJoin: .round))
                        .frame(width: radius * 2, height: radius * 2)
                        .position(center)
                        .allowsHitTesting(false)
                }

                ClockLabels(rates: rates, radius: radius, center: center)
                    .allowsHitTesting(false)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        select(at: value.location, center: center, radius: radius)
                    }
            )
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Agile half-hour price wheel")
            .accessibilityValue(accessibilityValue)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private func select(at point: CGPoint, center: CGPoint, radius: CGFloat) {
        guard !rates.isEmpty else { return }
        let dx = point.x - center.x
        let dy = point.y - center.y
        guard hypot(dx, dy) <= radius else { return }

        var degrees = atan2(dy, dx) * 180 / .pi + 90
        if degrees < 0 { degrees += 360 }
        let index = min(Int(degrees / (360 / Double(rates.count))), rates.count - 1)
        selectedRateID = rates[index].id
    }

    private var accessibilityValue: String {
        guard let id = selectedRateID,
              let rate = rates.first(where: { $0.id == id }) else { return "No selected price" }
        return "\(rate.validFrom.formatted(date: .omitted, time: .shortened)) to \(rate.validTo.formatted(date: .omitted, time: .shortened)), \(rate.valueIncVAT.formatted(.number.precision(.fractionLength(2)))) pence per kilowatt hour"
    }
}

private struct SectorOutline: Shape {
    let index: Int
    let count: Int

    func path(in rect: CGRect) -> Path {
        guard count > 0 else { return Path() }
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        let step = 360.0 / Double(count)
        let start = Angle.degrees(-90 + Double(index) * step)
        let end = Angle.degrees(-90 + Double(index + 1) * step)

        var path = Path()
        path.move(to: center)
        path.addArc(center: center, radius: radius, startAngle: start, endAngle: end, clockwise: false)
        path.closeSubpath()
        return path
    }
}

private struct ClockLabels: View {
    let rates: [HalfHourRate]
    let radius: CGFloat
    let center: CGPoint

    var body: some View {
        ZStack {
            ForEach(Array(rates.enumerated()), id: \.element.id) { index, rate in
                let hour = Calendar.uk.component(.hour, from: rate.validFrom)
                let minute = Calendar.uk.component(.minute, from: rate.validFrom)
                if minute == 0 && hour.isMultiple(of: 3) {
                    let step = 360.0 / Double(max(rates.count, 1))
                    let angle = (-90 + (Double(index) + 0.5) * step) * .pi / 180
                    Text(String(format: "%02d", hour))
                        .font(.caption2.bold())
                        .foregroundStyle(.white)
                        .shadow(radius: 1)
                        .position(
                            x: center.x + cos(angle) * radius * 0.79,
                            y: center.y + sin(angle) * radius * 0.79
                        )
                }
            }
        }
    }
}
