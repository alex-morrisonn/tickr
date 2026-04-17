import Foundation

struct RemoteCalendarService: CalendarService {
    static let calendarURL = URL(string: "https://raw.githubusercontent.com/MYUSERNAME/tickr-data/main/calendar.json")!

    private let session: URLSession
    private let fileManager: FileManager
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    private let now: @Sendable () -> Date
    private let cacheLifetime: TimeInterval

    init(
        session: URLSession = .shared,
        fileManager: FileManager = .default,
        now: @escaping @Sendable () -> Date = Date.init,
        cacheLifetime: TimeInterval = 6 * 60 * 60
    ) {
        self.session = session
        self.fileManager = fileManager
        self.now = now
        self.cacheLifetime = cacheLifetime

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder
    }

    func fetchEvents(from startDate: Date, to endDate: Date) async throws -> [EconomicEvent] {
        do {
            if try isCacheFresh() {
                let response = try loadCachedResponse()
                return filteredEvents(from: response.events, startDate: startDate, endDate: endDate)
            }

            let response = try await fetchRemoteResponse()
            try cache(response: response)
            return filteredEvents(from: response.events, startDate: startDate, endDate: endDate)
        } catch {
            if let cachedResponse = try? loadCachedResponse() {
                return filteredEvents(from: cachedResponse.events, startDate: startDate, endDate: endDate)
            }

            throw RemoteCalendarServiceError.noCachedData
        }
    }

    private func fetchRemoteResponse() async throws -> CalendarResponse {
        var request = URLRequest(url: Self.calendarURL)
        request.timeoutInterval = 30
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)
        try validate(response: response)

        do {
            return try decoder.decode(CalendarResponse.self, from: data)
        } catch {
            throw RemoteCalendarServiceError.invalidPayload
        }
    }

    private func validate(response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw RemoteCalendarServiceError.invalidResponse
        }

        guard 200..<300 ~= httpResponse.statusCode else {
            throw RemoteCalendarServiceError.requestFailed(statusCode: httpResponse.statusCode)
        }
    }

    private func filteredEvents(from events: [EconomicEvent], startDate: Date, endDate: Date) -> [EconomicEvent] {
        events
            .filter { $0.timestamp >= startDate && $0.timestamp <= endDate }
            .sorted { $0.timestamp < $1.timestamp }
    }

    private func cache(response: CalendarResponse) throws {
        let data = try encoder.encode(response)
        let cacheURL = try cacheFileURL()
        let directoryURL = cacheURL.deletingLastPathComponent()

        if !fileManager.fileExists(atPath: directoryURL.path) {
            try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        }

        try data.write(to: cacheURL, options: .atomic)
    }

    private func loadCachedResponse() throws -> CalendarResponse {
        let data = try Data(contentsOf: cacheFileURL())

        do {
            return try decoder.decode(CalendarResponse.self, from: data)
        } catch {
            throw RemoteCalendarServiceError.invalidPayload
        }
    }

    private func isCacheFresh() throws -> Bool {
        let cacheURL = try cacheFileURL()
        guard fileManager.fileExists(atPath: cacheURL.path) else {
            return false
        }

        let attributes = try fileManager.attributesOfItem(atPath: cacheURL.path)
        guard let modificationDate = attributes[.modificationDate] as? Date else {
            return false
        }

        return now().timeIntervalSince(modificationDate) < cacheLifetime
    }

    private func cacheFileURL() throws -> URL {
        guard let cachesDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            throw RemoteCalendarServiceError.cacheUnavailable
        }

        return cachesDirectory
            .appendingPathComponent("tickr", isDirectory: true)
            .appendingPathComponent("calendar-cache.json")
    }
}

enum RemoteCalendarServiceError: LocalizedError {
    case cacheUnavailable
    case invalidResponse
    case invalidPayload
    case requestFailed(statusCode: Int)
    case noCachedData

    var errorDescription: String? {
        switch self {
        case .cacheUnavailable:
            return "The local calendar cache is unavailable. Pull to refresh to try again."
        case .invalidResponse:
            return "The calendar feed returned an invalid response. Pull to refresh to try again."
        case .invalidPayload:
            return "The calendar feed JSON could not be parsed. Pull to refresh to try again."
        case let .requestFailed(statusCode):
            return "The calendar feed request failed with status \(statusCode). Pull to refresh to try again."
        case .noCachedData:
            return "No cached calendar data is available yet. Pull to refresh to try again."
        }
    }
}
