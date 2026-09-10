import SwiftUI

struct PriceColourScale {
    let min: Double
    let max: Double

    init(rates: [HalfHourRate]) {
        let values = rates.map(\.valueIncVAT)
        min = values.min() ?? 0
        max = values.max() ?? 1
    }

    func colour(for price: Double) -> Color {
        if price < 0 {
            return Color(hue: 0.57, saturation: 0.80, brightness: 0.92)
        }

        let positiveMin = Swift.max(0, min)
        let denominator = Swift.max(max - positiveMin, 0.001)
        let t = Swift.min(Swift.max((price - positiveMin) / denominator, 0), 1)
        // Day-relative: green (cheap) → yellow → red (expensive).
        let hue = 0.33 * (1 - t)
        return Color(hue: hue, saturation: 0.82, brightness: 0.92)
    }

    func band(for price: Double) -> String {
        if price < 0 { return "Negative price" }
        let span = Swift.max(max - min, 0.001)
        let t = (price - min) / span
        switch t {
        case ..<0.20: return "Very low"
        case ..<0.40: return "Low"
        case ..<0.60: return "Mid-range"
        case ..<0.80: return "High"
        default: return "Very high"
        }
    }
}
