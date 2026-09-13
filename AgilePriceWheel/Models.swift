import Foundation

struct ProductPage: Decodable {
    let count: Int
    let next: URL?
    let results: [ProductSummary]
}

struct ProductSummary: Decodable, Identifiable, Hashable {
    var id: String { code }
    let code: String
    let direction: String?
    let fullName: String
    let displayName: String
    let description: String?
    let availableFrom: Date?
    let availableTo: Date?
    let brand: String?

    enum CodingKeys: String, CodingKey {
        case code, direction, description, brand
        case fullName = "full_name"
        case displayName = "display_name"
        case availableFrom = "available_from"
        case availableTo = "available_to"
    }
}

struct ProductDetail: Decodable {
    let code: String
    let fullName: String
    let displayName: String
    let singleRegisterElectricityTariffs: [String: [String: ElectricityTariff]]

    enum CodingKeys: String, CodingKey {
        case code
        case fullName = "full_name"
        case displayName = "display_name"
        case singleRegisterElectricityTariffs = "single_register_electricity_tariffs"
    }
}

struct ElectricityTariff: Decodable, Hashable {
    let code: String
    let standingChargeIncVAT: Double?
    let links: [APILink]

    enum CodingKeys: String, CodingKey {
        case code, links
        case standingChargeIncVAT = "standing_charge_inc_vat"
    }
}

struct APILink: Decodable, Hashable {
    let href: URL
    let rel: String
}

struct TariffOption: Identifiable, Hashable, Codable {
    var id: String { tariffCode }
    let productCode: String
    let productName: String
    let tariffCode: String
    let regionCode: String
    let paymentMethod: String
    let standingChargeIncVAT: Double?

    var regionName: String {
        RegionNames.name(for: regionCode)
    }

    var displayName: String {
        "\(productName) · \(regionName)"
    }

    var subtitle: String {
        "\(tariffCode) · \(paymentMethod.replacingOccurrences(of: "_", with: " ").capitalized)"
    }
}

struct RatePage: Decodable {
    let count: Int
    let next: URL?
    let results: [HalfHourRate]
}

/// Codable rather than Decodable-only so downloaded rates can also be stored
/// in the app's persistent offline cache.
struct HalfHourRate: Codable, Identifiable, Hashable {
    let valueExcVAT: Double
    let valueIncVAT: Double
    let validFrom: Date
    let validTo: Date
    let paymentMethod: String?

    var id: Date { validFrom }

    enum CodingKeys: String, CodingKey {
        case valueExcVAT = "value_exc_vat"
        case valueIncVAT = "value_inc_vat"
        case validFrom = "valid_from"
        case validTo = "valid_to"
        case paymentMethod = "payment_method"
    }
}

enum RegionNames {
    private static let names: [String: String] = [
        "_A": "Eastern England",
        "_B": "East Midlands",
        "_C": "London",
        "_D": "Merseyside & North Wales",
        "_E": "West Midlands",
        "_F": "North East England",
        "_G": "North West England",
        "_H": "Southern England",
        "_J": "South East England",
        "_K": "South Wales",
        "_L": "South West England",
        "_M": "Yorkshire",
        "_N": "South Scotland",
        "_P": "North Scotland"
    ]

    static func name(for code: String) -> String {
        names[code] ?? code
    }
}
