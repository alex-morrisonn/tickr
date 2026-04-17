import Foundation

struct CalendarResponse: Codable {
    let weekOf: String
    let lastUpdated: Date
    let events: [EconomicEvent]
}
