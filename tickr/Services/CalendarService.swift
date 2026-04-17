import Foundation

protocol CalendarService {
    func fetchEvents(from startDate: Date, to endDate: Date) async throws -> [EconomicEvent]
}
