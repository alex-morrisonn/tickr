import Foundation

final class RemoteCalendarService: CalendarService {
    static let calendarURL = URL(string: "https://https://raw.githubusercontent.com/alex-morrisonn/tickr/refs/heads/main/tickr/SampleData/calendar.json")!

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
        cacheLifetime: TimeInterval = 24 * 60 * 60
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
        let response = try await loadResponse(forceRefresh: false)
        return filteredEvents(from: response.events, startDate: startDate, endDate: endDate)
    }

    func refreshEvents(from startDate: Date, to endDate: Date) async throws -> [EconomicEvent] {
        let response = try await loadResponse(forceRefresh: true)
        return filteredEvents(from: response.events, startDate: startDate, endDate: endDate)
    }

    private func filteredEvents(from events: [EconomicEvent], startDate: Date, endDate: Date) -> [EconomicEvent] {
        events
            .filter { $0.timestamp >= startDate && $0.timestamp <= endDate }
            .sorted { $0.timestamp < $1.timestamp }
    }

    private func loadResponse(forceRefresh: Bool) async throws -> CalendarResponse {
        do {
            if !forceRefresh, try isCacheFresh() {
                return try loadCachedResponse()
            }

            let remoteResponse = try await fetchRemoteResponse()
            try cache(response: remoteResponse)
            return remoteResponse
        } catch {
            if let cachedResponse = try? loadCachedResponse() {
                return cachedResponse
            }

            if let bundledResponse = try? loadBundledResponse() {
                return bundledResponse
            }

            throw RemoteCalendarServiceError.noDataAvailable
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

    private func loadBundledResponse() throws -> CalendarResponse {
        guard let fileURL = Bundle.main.url(forResource: "calendar", withExtension: "json", subdirectory: "SampleData")
            ?? Bundle.main.url(forResource: "calendar", withExtension: "json")
        else {
            throw RemoteCalendarServiceError.missingBundledFile
        }

        let data = try Data(contentsOf: fileURL)
        do {
            return try decoder.decode(CalendarResponse.self, from: data)
        } catch {
            throw RemoteCalendarServiceError.invalidPayload
        }
    }

    private func loadCachedResponse() throws -> CalendarResponse {
        let data = try Data(contentsOf: cacheFileURL())

        do {
            return try decoder.decode(CalendarResponse.self, from: data)
        } catch {
            throw RemoteCalendarServiceError.invalidPayload
        }
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
    case missingBundledFile
    case invalidResponse
    case invalidPayload
    case requestFailed(statusCode: Int)
    case noDataAvailable

    var errorDescription: String? {
        switch self {
        case .cacheUnavailable:
            return "The local calendar cache is unavailable."
        case .missingBundledFile:
            return "The bundled calendar.json file could not be found."
        case .invalidResponse:
            return "The remote calendar returned an invalid response."
        case .invalidPayload:
            return "The calendar.json file could not be parsed."
        case let .requestFailed(statusCode):
            return "The remote calendar request failed with status \(statusCode)."
        case .noDataAvailable:
            return "No calendar data is available. Pull to refresh to try again."
        }
    }
}
