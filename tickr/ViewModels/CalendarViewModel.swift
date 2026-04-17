import Foundation
import Observation

@MainActor
@Observable
final class CalendarViewModel {
    private let service: CalendarService

    var events: [EconomicEvent] = []
    var isLoading = false
    var errorMessage: String?

    init(service: CalendarService = RemoteCalendarService()) {
        self.service = service
    }

    func loadCurrentWeek() async {
        let interval = Calendar.currentWeekIntervalInUTC()
        await load(from: interval.start, to: interval.end)
    }

    func refresh() async {
        let interval = Calendar.currentWeekIntervalInUTC()
        await load(from: interval.start, to: interval.end)
    }

    private func load(from startDate: Date, to endDate: Date) async {
        isLoading = true
        errorMessage = nil

        do {
            events = try await service.fetchEvents(from: startDate, to: endDate)
        } catch {
            events = []
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}
