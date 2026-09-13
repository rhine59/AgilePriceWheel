import Foundation

/// Persistent on-device cache for tariff metadata and half-hour rates.
///
/// The cache lives in Application Support so it survives app launches and is
/// available when the network is unavailable. Every successfully downloaded
/// tariff list and every day of prices viewed by the user is retained locally.
@MainActor
final class AgileCacheStore {
    static let shared = AgileCacheStore()

    struct TariffSnapshot: Codable {
        let savedAt: Date
        let tariffs: [TariffOption]
    }

    struct RateSnapshot: Codable {
        let savedAt: Date
        let tariffCode: String
        let dayKey: String
        let rates: [HalfHourRate]
    }

    private let fileManager = FileManager.default
    private let baseDirectory: URL
    private let ratesDirectory: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    private init() {
        let support = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? fileManager.temporaryDirectory

        baseDirectory = support
            .appendingPathComponent("AgilePriceWheel", isDirectory: true)
        ratesDirectory = baseDirectory
            .appendingPathComponent("Rates", isDirectory: true)

        try? fileManager.createDirectory(
            at: ratesDirectory,
            withIntermediateDirectories: true
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    // MARK: - Tariffs

    func saveTariffs(_ tariffs: [TariffOption], savedAt: Date = Date()) {
        guard !tariffs.isEmpty else { return }
        let snapshot = TariffSnapshot(savedAt: savedAt, tariffs: tariffs)
        write(snapshot, to: tariffFileURL)
    }

    func loadTariffs() -> TariffSnapshot? {
        read(TariffSnapshot.self, from: tariffFileURL)
    }

    // MARK: - Rates

    func saveRates(
        _ rates: [HalfHourRate],
        tariff: TariffOption,
        localDate: Date,
        savedAt: Date = Date()
    ) {
        guard !rates.isEmpty else { return }
        let snapshot = RateSnapshot(
            savedAt: savedAt,
            tariffCode: tariff.tariffCode,
            dayKey: dayKey(for: localDate),
            rates: rates
        )
        write(snapshot, to: rateFileURL(tariff: tariff, localDate: localDate))
    }

    func loadRates(
        tariff: TariffOption,
        localDate: Date
    ) -> RateSnapshot? {
        read(
            RateSnapshot.self,
            from: rateFileURL(tariff: tariff, localDate: localDate)
        )
    }

    // MARK: - File locations

    private var tariffFileURL: URL {
        baseDirectory.appendingPathComponent("tariffs.json")
    }

    private func rateFileURL(
        tariff: TariffOption,
        localDate: Date
    ) -> URL {
        let filename = "\(safeFileComponent(tariff.tariffCode))_\(dayKey(for: localDate)).json"
        return ratesDirectory.appendingPathComponent(filename)
    }

    private func dayKey(for date: Date) -> String {
        let components = Calendar.uk.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }

    private func safeFileComponent(_ value: String) -> String {
        value.map { character in
            if character.isLetter || character.isNumber || character == "-" || character == "_" {
                return String(character)
            }
            return "_"
        }.joined()
    }

    // MARK: - JSON storage

    private func write<T: Encodable>(_ value: T, to url: URL) {
        do {
            let data = try encoder.encode(value)
            try data.write(to: url, options: [.atomic])
        } catch {
            // Cache writes are deliberately non-fatal. A failed cache write must
            // never prevent live tariff data from being displayed.
            print("AgilePriceWheel cache write failed: \(error.localizedDescription)")
        }
    }

    private func read<T: Decodable>(_ type: T.Type, from url: URL) -> T? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        do {
            return try decoder.decode(type, from: data)
        } catch {
            print("AgilePriceWheel cache read failed: \(error.localizedDescription)")
            return nil
        }
    }
}
