import Foundation
import Testing
@testable import tickr

@MainActor
struct EconomicEventDecodingTests {
    @Test
    func eventDecodesFromProductionCalendarSchema() throws {
        let json = """
        {
          "id": "2026-04-14-us-core-retail-sales",
          "title": "Core Retail Sales m/m",
          "country": "US",
          "currency": "USD",
          "timestamp": "2026-04-14T12:30:00Z",
          "impact": "high",
          "forecast": "0.4%",
          "previous": "0.6%",
          "actual": null,
          "category": "consumption",
          "relatedPairs": ["EURUSD", "GBPUSD", "USDJPY"]
        }
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let event = try decoder.decode(EconomicEvent.self, from: try #require(json.data(using: .utf8)))

        #expect(event.id == "2026-04-14-us-core-retail-sales")
        #expect(event.countryCode == "US")
        #expect(event.currencyCode == "USD")
        #expect(event.impactLevel == .high)
        #expect(event.category == "consumption")
        #expect(event.relatedPairs == ["EURUSD", "GBPUSD", "USDJPY"])
        #expect(event.actual == nil)
    }

    @Test
    func bundledCalendarJSONDecodesAndContainsLaunchData() throws {
        let fileURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("tickr/SampleData/calendar.json")
        let data = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let calendar = try decoder.decode(CalendarFixture.self, from: data)

        #expect(calendar.weekOf == "2026-04-13")
        #expect(!calendar.events.isEmpty)
        #expect(calendar.events.allSatisfy { !$0.id.isEmpty && !$0.title.isEmpty })
        #expect(calendar.events.allSatisfy { !$0.countryCode.isEmpty && !$0.currencyCode.isEmpty })
        #expect(calendar.events.contains { $0.impactLevel == .high })
        #expect(calendar.events.contains { !$0.relatedPairs.isEmpty })
    }
}

private struct CalendarFixture: Decodable {
    let weekOf: String
    let lastUpdated: Date
    let events: [EconomicEvent]
}
