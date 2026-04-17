import Foundation

struct EconomicEvent: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let countryCode: String
    let currencyCode: String
    let timestamp: Date
    let impactLevel: ImpactLevel
    let forecast: String?
    let previous: String?
    let actual: String?
    let category: String?
    let relatedPairs: [String]

    init(
        id: String = UUID().uuidString,
        title: String,
        countryCode: String,
        currencyCode: String,
        timestamp: Date,
        impactLevel: ImpactLevel,
        forecast: String? = nil,
        previous: String? = nil,
        actual: String? = nil,
        category: String? = nil,
        relatedPairs: [String] = []
    ) {
        self.id = id
        self.title = title
        self.countryCode = countryCode
        self.currencyCode = currencyCode
        self.timestamp = timestamp
        self.impactLevel = impactLevel
        self.forecast = forecast
        self.previous = previous
        self.actual = actual
        self.category = category
        self.relatedPairs = relatedPairs
    }

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case countryCode = "country"
        case currencyCode = "currency"
        case timestamp
        case impactLevel = "impact"
        case forecast
        case previous
        case actual
        case category
        case relatedPairs
    }
}
