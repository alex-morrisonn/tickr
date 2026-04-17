import Foundation
import Observation

@MainActor
@Observable
final class CalendarViewModel {
    private let service: CalendarService

    var events: [EconomicEvent] = []
    var isLoading = false
    var errorMessage: String?

    init(service: CalendarService) {
        self.service = service
    }

    func loadCurrentWeek() async {
        let interval = Calendar.currentWeekIntervalInUTC()
        await load(from: interval.start, to: interval.end)
    }

    func refresh() async {
        let interval = Calendar.currentWeekIntervalInUTC()
        await refresh(from: interval.start, to: interval.end)
    }

    private func load(from startDate: Date, to endDate: Date) async {
        isLoading = true
        errorMessage = nil

        do {
            events = try await service.fetchEvents(from: startDate, to: endDate)
            logDebugState(context: "load")
        } catch {
            events = []
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func refresh(from startDate: Date, to endDate: Date) async {
        isLoading = true
        errorMessage = nil

        do {
            if let remoteService = service as? RemoteCalendarService {
                events = try await remoteService.refreshEvents(from: startDate, to: endDate)
            } else {
                events = try await service.fetchEvents(from: startDate, to: endDate)
            }
            logDebugState(context: "refresh")
        } catch {
            events = []
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func logDebugState(context: String) {
        #if DEBUG
        let timezone = TimeZone.current.identifier
        let cacheBypass = (service as? RemoteCalendarService)?.isBypassingCacheForTesting ?? false

        if let firstEvent = events.first {
            let displayedTime = EventDateFormatter.timeFormatter.string(from: firstEvent.timestamp)
            print(
                """
                [Tickr Debug] \(context)
                timezone=\(timezone)
                cacheBypass=\(cacheBypass)
                firstEventID=\(firstEvent.id)
                firstEventTimestamp=\(firstEvent.timestamp.ISO8601Format())
                firstEventDisplayedTime=\(displayedTime)
                """
            )
        } else {
            print(
                """
                [Tickr Debug] \(context)
                timezone=\(timezone)
                cacheBypass=\(cacheBypass)
                eventCount=0
                """
            )
        }
        #endif
    }
}
