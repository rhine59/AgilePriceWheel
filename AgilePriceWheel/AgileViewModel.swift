import Foundation
import Combine

@MainActor
final class AgileViewModel: ObservableObject {
    @Published var tariffs: [TariffOption] = []
    @Published var selectedTariff: TariffOption?
    @Published var selectedDate: Date = Date()
    @Published var rates: [HalfHourRate] = []
    @Published var selectedRateID: Date?
    @Published var isLoadingTariffs = false
    @Published var isLoadingRates = false
    @Published var errorMessage: String?

    private let api = OctopusAPI.shared
    private let defaults = UserDefaults.standard
    private let savedTariffKey = "selectedTariffCode"

    var selectedRate: HalfHourRate? {
        guard let selectedRateID else { return nil }
        return rates.first { $0.id == selectedRateID }
    }

    var minPrice: Double? { rates.map(\.valueIncVAT).min() }
    var maxPrice: Double? { rates.map(\.valueIncVAT).max() }
    var averagePrice: Double? {
        guard !rates.isEmpty else { return nil }
        return rates.map(\.valueIncVAT).reduce(0, +) / Double(rates.count)
    }

    func start() async {
        guard tariffs.isEmpty else { return }
        await loadTariffs()
    }

    func loadTariffs() async {
        isLoadingTariffs = true
        errorMessage = nil
        defer { isLoadingTariffs = false }

        do {
            let loaded = try await api.availableAgileTariffs()
            tariffs = loaded

            if let saved = defaults.string(forKey: savedTariffKey),
               let match = loaded.first(where: { $0.tariffCode == saved }) {
                selectedTariff = match
            } else if let yorkshire = loaded.first(where: { $0.regionCode == "_M" }) {
                selectedTariff = yorkshire
            } else {
                selectedTariff = loaded.first
            }

            if selectedTariff != nil { await loadRates() }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func chooseTariff(_ tariff: TariffOption) async {
        selectedTariff = tariff
        defaults.set(tariff.tariffCode, forKey: savedTariffKey)
        await loadRates()
    }

    func loadRates() async {
        guard let selectedTariff else { return }
        isLoadingRates = true
        errorMessage = nil
        defer { isLoadingRates = false }

        do {
            rates = try await api.rates(for: selectedTariff, localDate: selectedDate)
            selectedRateID = currentOrFirstRateID()
            if rates.isEmpty {
                errorMessage = "No half-hour prices are published for this tariff/date yet. Agile next-day prices are normally published later in the day."
            }
        } catch {
            rates = []
            selectedRateID = nil
            errorMessage = error.localizedDescription
        }
    }

    func chooseRate(index: Int) {
        guard rates.indices.contains(index) else { return }
        selectedRateID = rates[index].id
    }

    private func currentOrFirstRateID() -> Date? {
        let now = Date()
        if let current = rates.first(where: { $0.validFrom <= now && now < $0.validTo }) {
            return current.id
        }
        return rates.first?.id
    }
}
