import Foundation

struct CurrencyPair: Identifiable, Codable, Hashable {
    var id: String { symbol }

    let symbol: String
    let base: String
    let quote: String
    var isWatched: Bool
}
