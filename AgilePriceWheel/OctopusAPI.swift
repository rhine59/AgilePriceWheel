import Foundation

/// Octopus Energy API client.
///
/// This is MainActor-isolated deliberately. The Xcode project uses Swift 6's
/// Main Actor default isolation, so the app's model types (ProductPage,
/// RatePage, TariffOption, etc.) are MainActor-isolated too. Keeping the API
/// client on the same actor removes the Swift 6 isolation warnings cleanly.
@MainActor
final class OctopusAPI {
    static let shared = OctopusAPI()

    private let session: URLSession
    private let decoder: JSONDecoder
    private let baseURL = URL(string: "https://api.octopus.energy/v1/")!

    private init(session: URLSession = .shared) {
        self.session = session

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    /// Returns the currently available Octopus Agile import tariffs.
    func availableAgileTariffs() async throws -> [TariffOption] {
        let products = try await fetchAllProducts()
        let now = Date()

        let agileProducts = products.filter { product in
            let isAgile =
                product.code.localizedCaseInsensitiveContains("AGILE") ||
                product.displayName.localizedCaseInsensitiveContains("AGILE") ||
                product.fullName.localizedCaseInsensitiveContains("AGILE")

            let isImport =
                product.direction == nil ||
                product.direction?.uppercased() == "IMPORT"

            let isOctopus =
                product.brand == nil ||
                product.brand?.uppercased() == "OCTOPUS_ENERGY"

            let isStillAvailable =
                product.availableTo.map { $0 > now } ?? true

            return isAgile && isImport && isOctopus && isStillAvailable
        }

        var options: [TariffOption] = []

        for product in agileProducts {
            let detail = try await fetchProductDetail(code: product.code)

            for (region, paymentMethods) in detail.singleRegisterElectricityTariffs {
                for (paymentMethod, tariff) in paymentMethods {
                    guard tariff.links.contains(where: {
                        $0.rel == "standard_unit_rates"
                    }) else {
                        continue
                    }

                    options.append(
                        TariffOption(
                            productCode: detail.code,
                            productName: detail.displayName,
                            tariffCode: tariff.code,
                            regionCode: region,
                            paymentMethod: paymentMethod,
                            standingChargeIncVAT: tariff.standingChargeIncVAT
                        )
                    )
                }
            }
        }

        return options.sorted { lhs, rhs in
            if lhs.productName != rhs.productName {
                return lhs.productName < rhs.productName
            }

            if lhs.regionName != rhs.regionName {
                return lhs.regionName < rhs.regionName
            }

            return lhs.paymentMethod < rhs.paymentMethod
        }
    }

    /// Fetches every half-hour unit rate for the selected UK local calendar day.
    ///
    /// On daylight-saving transition days this can correctly return 46 or 50
    /// half-hour periods instead of 48.
    func rates(
        for tariff: TariffOption,
        localDate: Date,
        calendar: Calendar = .uk
    ) async throws -> [HalfHourRate] {
        let start = calendar.startOfDay(for: localDate)

        guard let end = calendar.date(
            byAdding: .day,
            value: 1,
            to: start
        ) else {
            throw APIError.invalidDate
        }

        var components = URLComponents(
            url: baseURL
                .appendingPathComponent("products")
                .appendingPathComponent(tariff.productCode)
                .appendingPathComponent("electricity-tariffs")
                .appendingPathComponent(tariff.tariffCode)
                .appendingPathComponent("standard-unit-rates"),
            resolvingAgainstBaseURL: false
        )

        components?.queryItems = [
            URLQueryItem(
                name: "period_from",
                value: Self.isoUTC.string(from: start)
            ),
            URLQueryItem(
                name: "period_to",
                value: Self.isoUTC.string(from: end)
            ),
            URLQueryItem(
                name: "page_size",
                value: "100"
            )
        ]

        guard let url = components?.url else {
            throw APIError.badURL
        }

        var allRates: [HalfHourRate] = []
        var nextURL: URL? = url

        while let currentURL = nextURL {
            let page: RatePage = try await get(currentURL)
            allRates.append(contentsOf: page.results)
            nextURL = page.next
        }

        return allRates
            .filter {
                $0.validFrom >= start &&
                $0.validFrom < end
            }
            .sorted {
                $0.validFrom < $1.validFrom
            }
    }

    // MARK: - Products

    private func fetchAllProducts() async throws -> [ProductSummary] {
        var components = URLComponents(
            url: baseURL.appendingPathComponent("products"),
            resolvingAgainstBaseURL: false
        )

        components?.queryItems = [
            URLQueryItem(name: "page_size", value: "100")
        ]

        guard let firstURL = components?.url else {
            throw APIError.badURL
        }

        var products: [ProductSummary] = []
        var nextURL: URL? = firstURL

        while let currentURL = nextURL {
            let page: ProductPage = try await get(currentURL)
            products.append(contentsOf: page.results)
            nextURL = page.next
        }

        return products
    }

    private func fetchProductDetail(code: String) async throws -> ProductDetail {
        let url = baseURL
            .appendingPathComponent("products")
            .appendingPathComponent(code)

        return try await get(url)
    }

    // MARK: - Networking

    private func get<T: Decodable>(_ url: URL) async throws -> T {
        let (data, response) = try await session.data(from: url)

        guard
            let httpResponse = response as? HTTPURLResponse,
            (200..<300).contains(httpResponse.statusCode)
        else {
            throw APIError.badResponse(
                (response as? HTTPURLResponse)?.statusCode
            )
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decode(error)
        }
    }

    // MARK: - Date formatting

    private static let isoUTC: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()
}

// MARK: - API errors

enum APIError: LocalizedError {
    case badURL
    case invalidDate
    case badResponse(Int?)
    case decode(Error)

    var errorDescription: String? {
        switch self {
        case .badURL:
            return "Could not construct the Octopus API URL."

        case .invalidDate:
            return "Could not calculate the selected day."

        case .badResponse(let statusCode):
            if let statusCode {
                return "Octopus API returned HTTP \(statusCode)."
            } else {
                return "Octopus API returned an invalid response."
            }

        case .decode(let error):
            return "Could not read the Octopus response: \(error.localizedDescription)"
        }
    }
}

// MARK: - UK calendar

extension Calendar {
    nonisolated static var uk: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone =
            TimeZone(identifier: "Europe/London") ??
            TimeZone(secondsFromGMT: 0)!
        return calendar
    }
}
