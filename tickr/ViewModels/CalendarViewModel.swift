import Foundation
import Observation

@MainActor
@Observable
final class CalendarViewModel {
    private let service: CalendarService

    var events: [EconomicEvent] = []
    var isLoading = false
    var errorMessage: String?
    var lastRefreshDate: Date?
    var visibleInterval: DateInterval?

    init(service: CalendarService) {
        self.service = service
    }

    func loadCurrentWeek() async {
        let interval = Calendar.tradingWeekInterval()
        await load(interval: interval, forceRefresh: false)
    }

    func refresh() async {
        let interval = visibleInterval ?? Calendar.tradingWeekInterval()
        await load(interval: interval, forceRefresh: true)
    }

    func loadWeek(referenceDate: Date = Date(), weekOffset: Int = 0) async {
        let interval = Calendar.tradingWeekInterval(referenceDate: referenceDate, weekOffset: weekOffset)
        await load(interval: interval, forceRefresh: false)
    }

    func clearCache() throws {
        guard service is RemoteCalendarService else {
            return
        }

        try RemoteCalendarService.clearCache()
        lastRefreshDate = nil
    }

    private func load(interval: DateInterval, forceRefresh: Bool) async {
        isLoading = true
        errorMessage = nil
        visibleInterval = interval

        do {
            if forceRefresh, let remoteService = service as? RemoteCalendarService {
                events = try await remoteService.refreshEvents(from: interval.start, to: interval.end)
            } else {
                events = try await service.fetchEvents(from: interval.start, to: interval.end)
            }
            lastRefreshDate = Date()
        } catch {
            events = []
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    var availableCurrencies: [String] {
        Array(Set(events.map(\.currencyCode))).sorted()
    }

    var availablePairSymbols: [String] {
        Array(Set(events.flatMap(\.relatedPairs))).sorted()
    }

    func events(forPair symbol: String) -> [EconomicEvent] {
        events.filter { $0.relatedPairs.contains(symbol) }
    }

    func nextEvent(forPair symbol: String, now: Date = Date()) -> EconomicEvent? {
        events(forPair: symbol)
            .filter { $0.timestamp >= now }
            .min { $0.timestamp < $1.timestamp }
    }
}
