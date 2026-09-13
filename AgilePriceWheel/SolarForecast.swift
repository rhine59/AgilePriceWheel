import Foundation
import Combine

struct SiteLocation: Codable, Equatable, Hashable {
    let name: String
    let latitude: Double
    let longitude: Double

    var coordinateLabel: String {
        String(format: "%.5f, %.5f", latitude, longitude)
    }
}

struct SolarHalfHour: Codable, Identifiable, Hashable {
    let validFrom: Date
    let validTo: Date
    let wattsPerSquareMetre: Double

    var id: Date { validFrom }
}

struct SiteSearchResult: Identifiable, Hashable {
    let id: Int
    let name: String
    let admin1: String?
    let country: String?
    let latitude: Double
    let longitude: Double

    var displayName: String {
        [name, admin1, country]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
    }

    var siteLocation: SiteLocation {
        SiteLocation(name: displayName, latitude: latitude, longitude: longitude)
    }
}

@MainActor
final class SolarForecastModel: ObservableObject {
    enum DataOrigin: Equatable {
        case none
        case server(Date)
        case localCache(Date)
    }

    @Published private(set) var site: SiteLocation?
    @Published private(set) var forecast: [SolarHalfHour] = []
    @Published var selectedSolarID: Date?
    @Published private(set) var dataOrigin: DataOrigin = .none
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var syncMessage: String?
    @Published var searchResults: [SiteSearchResult] = []
    @Published var isSearchingSites = false

    private let api = SolarForecastAPI.shared
    private let cache = SolarForecastCache.shared
    private let defaults = UserDefaults.standard
    private let siteKey = "solarSiteLocation"

    init() {
        restoreSite()
    }

    var selectedSolar: SolarHalfHour? {
        guard let selectedSolarID else { return nil }
        return forecast.first { $0.id == selectedSolarID }
    }

    var maximumIrradiance: Double? {
        forecast.map(\.wattsPerSquareMetre).max()
    }

    var daylightAverage: Double? {
        let daylight = forecast.map(\.wattsPerSquareMetre).filter { $0 > 0.5 }
        guard !daylight.isEmpty else { return forecast.isEmpty ? nil : 0 }
        return daylight.reduce(0, +) / Double(daylight.count)
    }

    var dataSourceLabel: String {
        switch dataOrigin {
        case .none:
            return "NO SOLAR DATA"
        case .server(let date):
            return "SERVER DATA · updated \(shortTimestamp(date))"
        case .localCache(let date):
            return "LOCAL CACHE · saved \(shortTimestamp(date))"
        }
    }

    func loadForecast(for localDate: Date) async {
        errorMessage = nil
        syncMessage = nil

        guard site != nil else {
            forecast = []
            selectedSolarID = nil
            dataOrigin = .none
            return
        }

        restoreForecastFromCache(for: localDate, clearIfMissing: true)
        await refresh(for: localDate)
    }

    func refresh(for localDate: Date) async {
        guard let site else {
            errorMessage = "Set a solar forecast site in Settings first."
            forecast = []
            selectedSolarID = nil
            dataOrigin = .none
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let fresh = try await api.forecast(location: site, localDate: localDate)
            guard !fresh.isEmpty else {
                if let snapshot = cache.loadForecast(location: site, localDate: localDate), !snapshot.forecast.isEmpty {
                    applyForecast(snapshot.forecast)
                    dataOrigin = .localCache(snapshot.savedAt)
                    syncMessage = "No solar forecast was returned. Showing the saved local copy."
                    errorMessage = nil
                } else {
                    forecast = []
                    selectedSolarID = nil
                    dataOrigin = .none
                    errorMessage = "No solar irradiance forecast is available for this site/date."
                }
                return
            }

            let fetchedAt = Date()
            applyForecast(fresh)
            cache.saveForecast(fresh, location: site, localDate: localDate, savedAt: fetchedAt)
            dataOrigin = .server(fetchedAt)
            syncMessage = nil
            errorMessage = nil
        } catch {
            if let snapshot = cache.loadForecast(location: site, localDate: localDate), !snapshot.forecast.isEmpty {
                applyForecast(snapshot.forecast)
                dataOrigin = .localCache(snapshot.savedAt)
                syncMessage = "Solar server unavailable. Showing locally cached irradiance data."
                errorMessage = nil
            } else {
                forecast = []
                selectedSolarID = nil
                dataOrigin = .none
                errorMessage = "Could not download the solar forecast and there is no cached copy. \(error.localizedDescription)"
            }
        }
    }

    func setSite(_ newSite: SiteLocation, for localDate: Date) async {
        site = newSite
        persistSite(newSite)
        searchResults = []
        await loadForecast(for: localDate)
    }

    func setManualSite(name: String = "Custom site", latitude: Double, longitude: Double, for localDate: Date) async {
        let location = SiteLocation(name: name, latitude: latitude, longitude: longitude)
        await setSite(location, for: localDate)
    }

    func clearSite() {
        site = nil
        forecast = []
        selectedSolarID = nil
        dataOrigin = .none
        searchResults = []
        defaults.removeObject(forKey: siteKey)
    }

    func searchSites(_ query: String) async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            searchResults = []
            return
        }

        isSearchingSites = true
        defer { isSearchingSites = false }

        do {
            searchResults = try await api.searchLocations(trimmed)
            if searchResults.isEmpty {
                errorMessage = "No matching location was found. Try a nearby town or postcode, or enter latitude/longitude manually."
            } else {
                errorMessage = nil
            }
        } catch {
            searchResults = []
            errorMessage = "Location search failed. \(error.localizedDescription)"
        }
    }

    private func restoreSite() {
        guard let data = defaults.data(forKey: siteKey),
              let decoded = try? JSONDecoder().decode(SiteLocation.self, from: data) else {
            return
        }
        site = decoded
    }

    private func persistSite(_ site: SiteLocation) {
        if let data = try? JSONEncoder().encode(site) {
            defaults.set(data, forKey: siteKey)
        }
    }

    private func restoreForecastFromCache(for localDate: Date, clearIfMissing: Bool) {
        guard let site else { return }

        if let snapshot = cache.loadForecast(location: site, localDate: localDate), !snapshot.forecast.isEmpty {
            applyForecast(snapshot.forecast)
            dataOrigin = .localCache(snapshot.savedAt)
        } else if clearIfMissing {
            forecast = []
            selectedSolarID = nil
            dataOrigin = .none
        }
    }

    private func applyForecast(_ newForecast: [SolarHalfHour]) {
        let oldSelection = selectedSolarID
        forecast = newForecast

        if let oldSelection, newForecast.contains(where: { $0.id == oldSelection }) {
            selectedSolarID = oldSelection
        } else {
            let now = Date()
            selectedSolarID = newForecast.first(where: { $0.validFrom <= now && now < $0.validTo })?.id
                ?? newForecast.first?.id
        }
    }

    private func shortTimestamp(_ date: Date) -> String {
        if Calendar.uk.isDateInToday(date) {
            return date.formatted(.dateTime.hour().minute())
        }
        return date.formatted(.dateTime.day().month(.abbreviated).hour().minute())
    }
}

@MainActor
final class SolarForecastAPI {
    static let shared = SolarForecastAPI()

    private let session: URLSession
    private let decoder = JSONDecoder()

    private init(session: URLSession = .shared) {
        self.session = session
    }

    func forecast(location: SiteLocation, localDate: Date) async throws -> [SolarHalfHour] {
        let day = Self.dayKey(localDate)
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")
        components?.queryItems = [
            URLQueryItem(name: "latitude", value: String(location.latitude)),
            URLQueryItem(name: "longitude", value: String(location.longitude)),
            URLQueryItem(name: "minutely_15", value: "shortwave_radiation"),
            URLQueryItem(name: "timezone", value: "Europe/London"),
            URLQueryItem(name: "timeformat", value: "unixtime"),
            URLQueryItem(name: "start_date", value: day),
            URLQueryItem(name: "end_date", value: day)
        ]

        guard let url = components?.url else { throw SolarError.badURL }
        let (data, response) = try await session.data(from: url)
        try validate(response)

        let payload: ForecastResponse
        do {
            payload = try decoder.decode(ForecastResponse.self, from: data)
        } catch {
            throw SolarError.decode(error)
        }

        let count = min(payload.minutely15.time.count, payload.minutely15.shortwaveRadiation.count)
        guard count > 0 else { return [] }

        var samples: [(Date, Double)] = []
        samples.reserveCapacity(count)

        for index in 0..<count {
            guard let value = payload.minutely15.shortwaveRadiation[index] else { continue }
            let date = Date(timeIntervalSince1970: TimeInterval(payload.minutely15.time[index]))
            samples.append((date, max(0, value)))
        }

        var result: [SolarHalfHour] = []
        var index = 0
        while index < samples.count {
            let first = samples[index]
            guard Calendar.uk.isDate(first.0, inSameDayAs: localDate) else {
                index += 1
                continue
            }

            let secondValue: Double
            if index + 1 < samples.count,
               Calendar.uk.isDate(samples[index + 1].0, inSameDayAs: localDate) {
                secondValue = samples[index + 1].1
            } else {
                secondValue = first.1
            }

            let end = Calendar.uk.date(byAdding: .minute, value: 30, to: first.0)
                ?? first.0.addingTimeInterval(30 * 60)

            result.append(
                SolarHalfHour(
                    validFrom: first.0,
                    validTo: end,
                    wattsPerSquareMetre: (first.1 + secondValue) / 2
                )
            )
            index += 2
        }

        return result.sorted { $0.validFrom < $1.validFrom }
    }

    func searchLocations(_ query: String) async throws -> [SiteSearchResult] {
        var components = URLComponents(string: "https://geocoding-api.open-meteo.com/v1/search")
        components?.queryItems = [
            URLQueryItem(name: "name", value: query),
            URLQueryItem(name: "count", value: "8"),
            URLQueryItem(name: "language", value: "en"),
            URLQueryItem(name: "format", value: "json")
        ]

        guard let url = components?.url else { throw SolarError.badURL }
        let (data, response) = try await session.data(from: url)
        try validate(response)

        let payload: GeocodingResponse
        do {
            payload = try decoder.decode(GeocodingResponse.self, from: data)
        } catch {
            throw SolarError.decode(error)
        }

        return (payload.results ?? []).map {
            SiteSearchResult(
                id: $0.id,
                name: $0.name,
                admin1: $0.admin1,
                country: $0.country,
                latitude: $0.latitude,
                longitude: $0.longitude
            )
        }
    }

    private func validate(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode) else {
            throw SolarError.badResponse((response as? HTTPURLResponse)?.statusCode)
        }
    }

    nonisolated private static func dayKey(_ date: Date) -> String {
        let components = Calendar.uk.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
    }
}

@MainActor
final class SolarForecastCache {
    static let shared = SolarForecastCache()

    struct Snapshot: Codable {
        let savedAt: Date
        let location: SiteLocation
        let dayKey: String
        let forecast: [SolarHalfHour]
    }

    private let fileManager = FileManager.default
    private let directory: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    private init() {
        let support = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        directory = support
            .appendingPathComponent("AgilePriceWheel", isDirectory: true)
            .appendingPathComponent("Solar", isDirectory: true)
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    func saveForecast(_ forecast: [SolarHalfHour], location: SiteLocation, localDate: Date, savedAt: Date = Date()) {
        guard !forecast.isEmpty else { return }
        let snapshot = Snapshot(
            savedAt: savedAt,
            location: location,
            dayKey: Self.dayKey(localDate),
            forecast: forecast
        )
        do {
            let data = try encoder.encode(snapshot)
            try data.write(to: fileURL(location: location, localDate: localDate), options: [.atomic])
        } catch {
            print("Solar forecast cache write failed: \(error.localizedDescription)")
        }
    }

    func loadForecast(location: SiteLocation, localDate: Date) -> Snapshot? {
        let url = fileURL(location: location, localDate: localDate)
        guard let data = try? Data(contentsOf: url) else { return nil }
        do {
            return try decoder.decode(Snapshot.self, from: data)
        } catch {
            print("Solar forecast cache read failed: \(error.localizedDescription)")
            return nil
        }
    }

    private func fileURL(location: SiteLocation, localDate: Date) -> URL {
        let coordinate = String(format: "%.4f_%.4f", location.latitude, location.longitude)
            .replacingOccurrences(of: "-", with: "m")
            .replacingOccurrences(of: ".", with: "p")
        return directory.appendingPathComponent("\(coordinate)_\(Self.dayKey(localDate)).json")
    }

    nonisolated private static func dayKey(_ date: Date) -> String {
        let components = Calendar.uk.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
    }
}

private struct ForecastResponse: Decodable {
    let minutely15: Minutely15

    enum CodingKeys: String, CodingKey {
        case minutely15 = "minutely_15"
    }
}

private struct Minutely15: Decodable {
    let time: [Int]
    let shortwaveRadiation: [Double?]

    enum CodingKeys: String, CodingKey {
        case time
        case shortwaveRadiation = "shortwave_radiation"
    }
}

private struct GeocodingResponse: Decodable {
    let results: [GeocodingItem]?
}

private struct GeocodingItem: Decodable {
    let id: Int
    let name: String
    let latitude: Double
    let longitude: Double
    let country: String?
    let admin1: String?
}

enum SolarError: LocalizedError {
    case badURL
    case badResponse(Int?)
    case decode(Error)

    var errorDescription: String? {
        switch self {
        case .badURL:
            return "Could not construct the solar forecast request."
        case .badResponse(let code):
            return code.map { "Solar forecast service returned HTTP \($0)." }
                ?? "Solar forecast service returned an invalid response."
        case .decode(let error):
            return "Could not read the solar forecast response: \(error.localizedDescription)"
        }
    }
}
