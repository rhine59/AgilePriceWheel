import Foundation
import Combine

/// Persistent application settings that are not tied to one API response.
///
/// Solar-array values are stored now so they can be used later by a PV-output
/// model. The current solar forecast remains irradiance in W/m² and does not
/// yet convert these settings into predicted electrical generation.
@MainActor
final class AppSettingsStore: ObservableObject {
    @Published var arrayName: String { didSet { defaults.set(arrayName, forKey: Keys.arrayName) } }
    @Published var peakPowerKWpText: String { didSet { defaults.set(peakPowerKWpText, forKey: Keys.peakPowerKWp) } }
    @Published var panelCountText: String { didSet { defaults.set(panelCountText, forKey: Keys.panelCount) } }
    @Published var panelPowerWattsText: String { didSet { defaults.set(panelPowerWattsText, forKey: Keys.panelPowerWatts) } }
    @Published var tiltDegreesText: String { didSet { defaults.set(tiltDegreesText, forKey: Keys.tiltDegrees) } }
    @Published var azimuthDegreesText: String { didSet { defaults.set(azimuthDegreesText, forKey: Keys.azimuthDegrees) } }
    @Published var inverterMaxKWText: String { didSet { defaults.set(inverterMaxKWText, forKey: Keys.inverterMaxKW) } }
    @Published var systemLossPercentText: String { didSet { defaults.set(systemLossPercentText, forKey: Keys.systemLossPercent) } }
    @Published var notes: String { didSet { defaults.set(notes, forKey: Keys.notes) } }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        arrayName = defaults.string(forKey: Keys.arrayName) ?? ""
        peakPowerKWpText = defaults.string(forKey: Keys.peakPowerKWp) ?? ""
        panelCountText = defaults.string(forKey: Keys.panelCount) ?? ""
        panelPowerWattsText = defaults.string(forKey: Keys.panelPowerWatts) ?? ""
        tiltDegreesText = defaults.string(forKey: Keys.tiltDegrees) ?? ""
        azimuthDegreesText = defaults.string(forKey: Keys.azimuthDegrees) ?? ""
        inverterMaxKWText = defaults.string(forKey: Keys.inverterMaxKW) ?? ""
        systemLossPercentText = defaults.string(forKey: Keys.systemLossPercent) ?? ""
        notes = defaults.string(forKey: Keys.notes) ?? ""
    }

    var peakPowerKWp: Double? { decimal(from: peakPowerKWpText) }
    var panelCount: Int? { Int(panelCountText.trimmingCharacters(in: .whitespacesAndNewlines)) }
    var panelPowerWatts: Double? { decimal(from: panelPowerWattsText) }
    var tiltDegrees: Double? { decimal(from: tiltDegreesText) }
    var azimuthDegrees: Double? { decimal(from: azimuthDegreesText) }
    var inverterMaxKW: Double? { decimal(from: inverterMaxKWText) }
    var systemLossPercent: Double? { decimal(from: systemLossPercentText) }

    var calculatedPanelPeakKWp: Double? {
        guard let panelCount, panelCount > 0,
              let panelPowerWatts, panelPowerWatts > 0 else { return nil }
        return Double(panelCount) * panelPowerWatts / 1000.0
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
        static let arrayName = "solarArray.name"
        static let peakPowerKWp = "solarArray.peakPowerKWp"
        static let panelCount = "solarArray.panelCount"
        static let panelPowerWatts = "solarArray.panelPowerWatts"
        static let tiltDegrees = "solarArray.tiltDegrees"
        static let azimuthDegrees = "solarArray.azimuthDegrees"
        static let inverterMaxKW = "solarArray.inverterMaxKW"
        static let systemLossPercent = "solarArray.systemLossPercent"
        static let notes = "solarArray.notes"
    }
}
