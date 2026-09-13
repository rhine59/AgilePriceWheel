import Foundation
import Combine

@MainActor
final class AgileViewModel: ObservableObject {
    enum DataOrigin: Equatable {
        case none
        case server(Date)
        case localCache(Date)
    }

    @Published var tariffs: [TariffOption] = []
    @Published var selectedTariff: TariffOption?
    @Published var selectedDate: Date = Date()
    @Published var rates: [HalfHourRate] = []
    @Published var selectedRateID: Date?
    @Published var isLoadingTariffs = false
    @Published var isLoadingRates = false
    @Published var errorMessage: String?
    @Published var syncMessage: String?
    @Published private(set) var dataOrigin: DataOrigin = .none

    private let api = OctopusAPI.shared
    private let cache = AgileCacheStore.shared
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

    var isUsingCachedData: Bool {
        if case .localCache = dataOrigin { return true }
        return false
    }

    var dataSourceLabel: String {
        switch dataOrigin {
        case .none:
            return "NO DATA"
        case .server(let updatedAt):
            return "SERVER DATA · updated \(shortTimestamp(updatedAt))"
        case .localCache(let savedAt):
            return "LOCAL CACHE · saved \(shortTimestamp(savedAt))"
        }
    }

    // MARK: - Startup

    /// Restores local data immediately, then attempts to replace it with fresh
    /// server data. The UI therefore remains useful even if the app launches
    /// without a network connection.
    func start() async {
        guard tariffs.isEmpty else { return }

        restoreTariffsFromCache()
        restoreRatesFromCache()

        await refresh()
    }

    // MARK: - User actions

    /// Explicit refresh used by the UI. It refreshes tariff metadata and the
    /// currently selected day's rates. If either request fails, cached data is
    /// retained and the on-screen source indicator changes to LOCAL CACHE.
    func refresh() async {
        syncMessage = nil
        errorMessage = nil

        await refreshTariffsFromServer()

        guard selectedTariff != nil else {
            if tariffs.isEmpty {
                errorMessage = "No Agile tariff data is available from the server or local cache."
            }
            return
        }

        await refreshRatesFromServer()
    }

    /// Kept as a public action for the tariff picker refresh button.
    func loadTariffs() async {
        await refresh()
    }

    /// Loads any local copy for the selected tariff/date first, then attempts a
    /// live server refresh. This makes date changes work while offline.
    func loadRates() async {
        errorMessage = nil
        syncMessage = nil

        restoreRatesFromCache(clearIfMissing: true)
        await refreshRatesFromServer()
    }

    func chooseTariff(_ tariff: TariffOption) async {
        selectedTariff = tariff
        defaults.set(tariff.tariffCode, forKey: savedTariffKey)
        await loadRates()
    }

    func chooseRate(index: Int) {
        guard rates.indices.contains(index) else { return }
        selectedRateID = rates[index].id
    }

    // MARK: - Tariffs

    private func restoreTariffsFromCache() {
        guard let snapshot = cache.loadTariffs(), !snapshot.tariffs.isEmpty else {
            return
        }

        tariffs = snapshot.tariffs
        selectPreferredTariff(from: snapshot.tariffs, preservingCurrent: true)
    }

    private func refreshTariffsFromServer() async {
        isLoadingTariffs = true
        defer { isLoadingTariffs = false }

        let currentTariffCode = selectedTariff?.tariffCode

        do {
            let loaded = try await api.availableAgileTariffs()
            guard !loaded.isEmpty else {
                if tariffs.isEmpty {
                    restoreTariffsFromCache()
                }
                if !tariffs.isEmpty {
                    syncMessage = "The server returned no tariff list. Using locally cached tariff information."
                }
                return
            }

            tariffs = loaded
            cache.saveTariffs(loaded)

            if let currentTariffCode,
               let sameTariff = loaded.first(where: { $0.tariffCode == currentTariffCode }) {
                selectedTariff = sameTariff
            } else {
                selectPreferredTariff(from: loaded, preservingCurrent: false)
            }
        } catch {
            if tariffs.isEmpty {
                restoreTariffsFromCache()
            }

            if tariffs.isEmpty {
                errorMessage = "Could not download Agile tariffs and no cached tariff list is available. \(error.localizedDescription)"
            } else {
                syncMessage = "Tariff refresh failed. Using locally cached tariff information."
            }
        }
    }

    private func selectPreferredTariff(
        from available: [TariffOption],
        preservingCurrent: Bool
    ) {
        if preservingCurrent,
           let current = selectedTariff,
           let match = available.first(where: { $0.tariffCode == current.tariffCode }) {
            selectedTariff = match
            return
        }

        if let saved = defaults.string(forKey: savedTariffKey),
           let match = available.first(where: { $0.tariffCode == saved }) {
            selectedTariff = match
        } else if let yorkshire = available.first(where: { $0.regionCode == "_M" }) {
            selectedTariff = yorkshire
        } else {
            selectedTariff = available.first
        }
    }

    // MARK: - Rates

    private func restoreRatesFromCache(clearIfMissing: Bool = false) {
        guard let selectedTariff else {
            if clearIfMissing {
                rates = []
                selectedRateID = nil
                dataOrigin = .none
            }
            return
        }

        if let snapshot = cache.loadRates(
            tariff: selectedTariff,
            localDate: selectedDate
        ), !snapshot.rates.isEmpty {
            applyRates(snapshot.rates)
            dataOrigin = .localCache(snapshot.savedAt)
        } else if clearIfMissing {
            rates = []
            selectedRateID = nil
            dataOrigin = .none
        }
    }

    private func refreshRatesFromServer() async {
        guard let selectedTariff else { return }

        isLoadingRates = true
        defer { isLoadingRates = false }

        do {
            let freshRates = try await api.rates(
                for: selectedTariff,
                localDate: selectedDate
            )

            guard !freshRates.isEmpty else {
                if let snapshot = cache.loadRates(
                    tariff: selectedTariff,
                    localDate: selectedDate
                ), !snapshot.rates.isEmpty {
                    applyRates(snapshot.rates)
                    dataOrigin = .localCache(snapshot.savedAt)
                    syncMessage = "No prices were returned by the server for this day. Showing the saved local copy."
                } else {
                    rates = []
                    selectedRateID = nil
                    dataOrigin = .none
                    errorMessage = "No half-hour prices are published for this tariff/date yet. Agile next-day prices are normally published later in the day."
                }
                return
            }

            let fetchedAt = Date()
            applyRates(freshRates)
            cache.saveRates(
                freshRates,
                tariff: selectedTariff,
                localDate: selectedDate,
                savedAt: fetchedAt
            )
            dataOrigin = .server(fetchedAt)
            syncMessage = nil
            errorMessage = nil
        } catch {
            if let snapshot = cache.loadRates(
                tariff: selectedTariff,
                localDate: selectedDate
            ), !snapshot.rates.isEmpty {
                applyRates(snapshot.rates)
                dataOrigin = .localCache(snapshot.savedAt)
                syncMessage = "Server unavailable. Showing locally cached prices. Tap Refresh when a network connection is available."
                errorMessage = nil
            } else {
                rates = []
                selectedRateID = nil
                dataOrigin = .none
                errorMessage = "Could not download prices and there is no cached copy for this tariff/date. \(error.localizedDescription)"
            }
        }
    }

    private func applyRates(_ newRates: [HalfHourRate]) {
        let previousSelection = selectedRateID
        rates = newRates

        if let previousSelection,
           newRates.contains(where: { $0.id == previousSelection }) {
            selectedRateID = previousSelection
        } else {
            selectedRateID = currentOrFirstRateID()
        }
    }

    private func currentOrFirstRateID() -> Date? {
        let now = Date()
        if let current = rates.first(where: { $0.validFrom <= now && now < $0.validTo }) {
            return current.id
        }
        return rates.first?.id
    }

    private func shortTimestamp(_ date: Date) -> String {
        if Calendar.uk.isDateInToday(date) {
            return date.formatted(.dateTime.hour().minute())
        }
        return date.formatted(.dateTime.day().month(.abbreviated).hour().minute())
    }
}
