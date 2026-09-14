import Foundation
import Combine

/// Persistent application settings that are not tied to one API response.
///
/// Solar-array values are used by the PV generation estimate screen. The
/// optimiser load is used by the net/effective electricity-price screen.
@MainActor
final class AppSettingsStore: ObservableObject {
    @Published var hasPVPanelsInstalled: Bool { didSet { defaults.set(hasPVPanelsInstalled, forKey: Keys.hasPVPanelsInstalled) } }
    @Published var arrayName: String { didSet { defaults.set(arrayName, forKey: Keys.arrayName) } }
    @Published var peakPowerKWpText: String { didSet { defaults.set(peakPowerKWpText, forKey: Keys.peakPowerKWp) } }
    @Published var panelCountText: String { didSet { defaults.set(panelCountText, forKey: Keys.panelCount) } }
    @Published var panelPowerWattsText: String { didSet { defaults.set(panelPowerWattsText, forKey: Keys.panelPowerWatts) } }
    @Published var tiltDegreesText: String { didSet { defaults.set(tiltDegreesText, forKey: Keys.tiltDegrees) } }
    @Published var azimuthDegreesText: String { didSet { defaults.set(azimuthDegreesText, forKey: Keys.azimuthDegrees) } }
    @Published var inverterMaxKWText: String { didSet { defaults.set(inverterMaxKWText, forKey: Keys.inverterMaxKW) } }
    @Published var systemLossPercentText: String { didSet { defaults.set(systemLossPercentText, forKey: Keys.systemLossPercent) } }
    @Published var optimiserLoadKWText: String { didSet { defaults.set(optimiserLoadKWText, forKey: Keys.optimiserLoadKW) } }
    @Published var notes: String { didSet { defaults.set(notes, forKey: Keys.notes) } }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if defaults.object(forKey: Keys.hasPVPanelsInstalled) == nil {
            hasPVPanelsInstalled = true
        } else {
            hasPVPanelsInstalled = defaults.bool(forKey: Keys.hasPVPanelsInstalled)
        }
        arrayName = defaults.string(forKey: Keys.arrayName) ?? ""
        peakPowerKWpText = defaults.string(forKey: Keys.peakPowerKWp) ?? ""
        panelCountText = defaults.string(forKey: Keys.panelCount) ?? ""
        panelPowerWattsText = defaults.string(forKey: Keys.panelPowerWatts) ?? ""
        tiltDegreesText = defaults.string(forKey: Keys.tiltDegrees) ?? ""
        azimuthDegreesText = defaults.string(forKey: Keys.azimuthDegrees) ?? ""
        inverterMaxKWText = defaults.string(forKey: Keys.inverterMaxKW) ?? ""
        systemLossPercentText = defaults.string(forKey: Keys.systemLossPercent) ?? ""
        optimiserLoadKWText = defaults.string(forKey: Keys.optimiserLoadKW) ?? "3.0"
        notes = defaults.string(forKey: Keys.notes) ?? ""
    }

    var peakPowerKWp: Double? { decimal(from: peakPowerKWpText) }
    var panelCount: Int? { Int(panelCountText.trimmingCharacters(in: .whitespacesAndNewlines)) }
    var panelPowerWatts: Double? { decimal(from: panelPowerWattsText) }
    var tiltDegrees: Double? { decimal(from: tiltDegreesText) }
    var azimuthDegrees: Double? { decimal(from: azimuthDegreesText) }
    var inverterMaxKW: Double? { decimal(from: inverterMaxKWText) }
    var systemLossPercent: Double? { decimal(from: systemLossPercentText) }
    var optimiserLoadKW: Double? { decimal(from: optimiserLoadKWText) }

    var calculatedPanelPeakKWp: Double? {
        guard let panelCount, panelCount > 0,
              let panelPowerWatts, panelPowerWatts > 0 else { return nil }
        return Double(panelCount) * panelPowerWatts / 1000.0
    }

    /// Rated array capacity used by the generation estimate. An explicitly
    /// entered kWp value takes priority; otherwise panel count × panel watts is
    /// used when both are available.
    var effectivePeakPowerKWp: Double? {
        if let peakPowerKWp, peakPowerKWp > 0 { return peakPowerKWp }
        return calculatedPanelPeakKWp
    }

    /// Multiplicative factor after user-configured system losses. A blank loss
    /// field means no additional loss correction is applied.
    var generationLossFactor: Double {
        let percent = min(max(systemLossPercent ?? 0, 0), 100)
        return 1.0 - percent / 100.0
    }

    var effectiveInverterMaxKW: Double? {
        guard let inverterMaxKW, inverterMaxKW > 0 else { return nil }
        return inverterMaxKW
    }

    /// Controllable load used by the net/effective price optimiser. The
    /// historic nightly email model used 3.0 kW, so new installs default to
    /// that value while still allowing the user to change it.
    var effectiveOptimiserLoadKW: Double? {
        guard let optimiserLoadKW, optimiserLoadKW > 0 else { return nil }
        return optimiserLoadKW
    }

    var hasArrayDetails: Bool {
        !arrayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        peakPowerKWp != nil || panelCount != nil || panelPowerWatts != nil ||
        tiltDegrees != nil || azimuthDegrees != nil || inverterMaxKW != nil
    }

    func clearSolarArray() {
        arrayName = ""
        peakPowerKWpText = ""
        panelCountText = ""
        panelPowerWattsText = ""
        tiltDegreesText = ""
        azimuthDegreesText = ""
        inverterMaxKWText = ""
        systemLossPercentText = ""
        notes = ""
    }

    private func decimal(from text: String) -> Double? {
        let normalized = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
        return Double(normalized)
    }

    private enum Keys {
        static let hasPVPanelsInstalled = "solarArray.installed"
        static let arrayName = "solarArray.name"
        static let peakPowerKWp = "solarArray.peakPowerKWp"
        static let panelCount = "solarArray.panelCount"
        static let panelPowerWatts = "solarArray.panelPowerWatts"
        static let tiltDegrees = "solarArray.tiltDegrees"
        static let azimuthDegrees = "solarArray.azimuthDegrees"
        static let inverterMaxKW = "solarArray.inverterMaxKW"
        static let systemLossPercent = "solarArray.systemLossPercent"
        static let optimiserLoadKW = "optimiser.loadKW"
        static let notes = "solarArray.notes"
    }
}
