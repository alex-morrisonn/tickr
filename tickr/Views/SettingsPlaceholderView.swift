import SwiftUI
import UserNotifications

@MainActor
struct SessionsKillzonesView: View {
    let viewModel: CalendarViewModel
    @Bindable var preferences: UserPreferences

    @State private var notificationMessage: String?

    private let sessionDefinitions = ForexSessionDefinition.allCases
    private let overlapDefinitions = ForexOverlapDefinition.allCases

    var body: some View {
        ScrollView {
            TickrScreen {
                VStack(alignment: .leading, spacing: TickrLayout.sectionSpacing) {
                    TickrSectionHeader(
                        eyebrow: "Market Time",
                        title: "Sessions",
                        subtitle: "Track the major forex sessions, their overlaps, and get notified before they begin."
                    )

                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        let sessionStates = sessionDefinitions.map { SessionState(definition: $0, now: context.date) }
                        let overlapStates = overlapDefinitions.map { OverlapState(definition: $0, now: context.date) }

                        VStack(alignment: .leading, spacing: TickrLayout.sectionSpacing) {
                            overviewCard(sessionStates: sessionStates, overlapStates: overlapStates, now: context.date)
                            timelineCard(sessionStates: sessionStates)
                            sessionsCard(sessionStates: sessionStates)
                            overlapsCard(overlapStates: overlapStates)
                            notificationsCard(sessionStates: sessionStates, overlapStates: overlapStates)
                        }
                    }
                }
            }
        }
        .background(Color.clear)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Tickr")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(TickrPalette.text)
            }
        }
        .alert("Session Notification", isPresented: notificationAlertBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(notificationMessage ?? "")
        }
    }

    private func overviewCard(sessionStates: [SessionState], overlapStates: [OverlapState], now: Date) -> some View {
        TickrCard {
            VStack(alignment: .leading, spacing: 16) {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(headline(sessionStates: sessionStates, overlapStates: overlapStates))
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundStyle(TickrPalette.text)

                            Text(subheadline(sessionStates: sessionStates, overlapStates: overlapStates, now: now))
                                .font(.subheadline)
                                .foregroundStyle(TickrPalette.muted)
                        }

                        Spacer()

                        TickrPill(text: localTimeZoneLabel)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(headline(sessionStates: sessionStates, overlapStates: overlapStates))
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundStyle(TickrPalette.text)

                            Text(subheadline(sessionStates: sessionStates, overlapStates: overlapStates, now: now))
                                .font(.subheadline)
                                .foregroundStyle(TickrPalette.muted)
                        }

                        TickrPill(text: localTimeZoneLabel)
                    }
                }

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: TickrLayout.compactItemSpacing) {
                        TickrMetricCard(title: "Open now", value: "\(sessionStates.filter(\.isActive).count)")
                        TickrMetricCard(title: "Overlap", value: activeOverlapName(overlapStates: overlapStates))
                        TickrMetricCard(title: "Next start", value: nextStartCountdown(sessionStates: sessionStates, overlapStates: overlapStates, now: now))
                    }

                    VStack(spacing: TickrLayout.compactItemSpacing) {
                        TickrMetricCard(title: "Open now", value: "\(sessionStates.filter(\.isActive).count)")
                        TickrMetricCard(title: "Overlap", value: activeOverlapName(overlapStates: overlapStates))
                        TickrMetricCard(title: "Next start", value: nextStartCountdown(sessionStates: sessionStates, overlapStates: overlapStates, now: now))
                    }
                }
            }
        }
    }

    private func timelineCard(sessionStates: [SessionState]) -> some View {
        TickrCard {
            VStack(alignment: .leading, spacing: 16) {
                Text("Session Clock")
                    .font(.headline)
                    .foregroundStyle(TickrPalette.text)

                SessionTimelineView(sessionStates: sessionStates)
                    .frame(height: 168)
            }
        }
    }

    private func sessionsCard(sessionStates: [SessionState]) -> some View {
        TickrCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("Sessions")
                    .font(.headline)
                    .foregroundStyle(TickrPalette.text)

                ForEach(sessionStates) { state in
                    HStack(alignment: .top, spacing: 12) {
                        RoundedRectangle(cornerRadius: 999, style: .continuous)
                            .fill(state.definition.color)
                            .frame(width: 8, height: 44)
                            .opacity(state.isActive ? 1 : 0.35)

                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 8) {
                                Text(state.definition.title)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(TickrPalette.text)

                                if state.isActive {
                                    Text("Live")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(state.definition.color)
                                }
                            }

                            Text(state.localWindowLabel)
                                .font(.caption)
                                .foregroundStyle(TickrPalette.muted)
                        }

                        Spacer()

                        Text(state.isActive ? "Closes in \(state.closeRelativeLabel)" : "Opens in \(state.openRelativeLabel)")
                            .font(.caption.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(TickrPalette.muted)
                    }
                }
            }
        }
    }

    private func overlapsCard(overlapStates: [OverlapState]) -> some View {
        TickrCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("Overlaps")
                    .font(.headline)
                    .foregroundStyle(TickrPalette.text)

                ForEach(overlapStates) { overlap in
                    HStack(alignment: .top, spacing: 12) {
                        Circle()
                            .fill(overlap.definition.color)
                            .frame(width: 10, height: 10)
                            .padding(.top, 5)
                            .opacity(overlap.isActive ? 1 : 0.45)

                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 8) {
                                Text(overlap.definition.title)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(TickrPalette.text)

                                if overlap.isActive {
                                    Text("Live")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(overlap.definition.color)
                                }
                            }

                            Text(overlap.localWindowLabel)
                                .font(.caption)
                                .foregroundStyle(TickrPalette.muted)

                            Text(overlap.definition.note)
                                .font(.caption)
                                .foregroundStyle(TickrPalette.muted)
                        }

                        Spacer()

                        Text(overlap.isActive ? "Ends in \(overlap.endRelativeLabel)" : "Starts in \(overlap.startRelativeLabel)")
                            .font(.caption.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(TickrPalette.muted)
                    }
                }
            }
        }
    }

    private func notificationsCard(sessionStates: [SessionState], overlapStates: [OverlapState]) -> some View {
        TickrCard {
            VStack(alignment: .leading, spacing: 16) {
                Text("Notifications")
                    .font(.headline)
                    .foregroundStyle(TickrPalette.text)

                Text("Get a 15-minute warning before a session opens or an overlap begins.")
                    .font(.subheadline)
                    .foregroundStyle(TickrPalette.muted)

                ForEach(sessionStates) { state in
                    Toggle(isOn: sessionNotificationBinding(for: state.definition)) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(state.definition.title) open")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(TickrPalette.text)

                            Text("Alerts 15 minutes before \(state.definition.shortTitle) starts.")
                                .font(.caption)
                                .foregroundStyle(TickrPalette.muted)
                        }
                    }
                    .tint(TickrPalette.accent)
                }

                Divider()
                    .overlay(TickrPalette.stroke)

                ForEach(overlapStates) { overlap in
                    Toggle(isOn: overlapNotificationBinding(for: overlap.definition)) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(overlap.definition.title) start")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(TickrPalette.text)

                            Text("Alerts 15 minutes before the overlap begins.")
                                .font(.caption)
                                .foregroundStyle(TickrPalette.muted)
                        }
                    }
                    .tint(TickrPalette.accent)
                }
            }
        }
    }

    private func headline(sessionStates: [SessionState], overlapStates: [OverlapState]) -> String {
        if !SessionPresentation.isForexMarketOpen(at: Date()) {
            return "Forex market is closed"
        }

        if let activeOverlap = overlapStates.first(where: \.isActive) {
            return "\(activeOverlap.definition.shortTitle) overlap is live"
        }

        if let activeSession = sessionStates.first(where: \.isActive) {
            return "\(activeSession.definition.shortTitle) session is live"
        }

        return "No major session is open"
    }

    private func subheadline(sessionStates: [SessionState], overlapStates: [OverlapState], now: Date) -> String {
        if !SessionPresentation.isForexMarketOpen(at: now) {
            return "Reopens in \(SessionPresentation.relativeCountdown(to: SessionPresentation.nextForexMarketOpen(after: now), from: now))"
        }

        if let activeOverlap = overlapStates.first(where: \.isActive) {
            return "Ends in \(SessionPresentation.relativeCountdown(to: activeOverlap.activeInterval.end, from: now))"
        }

        if let activeSession = sessionStates.first(where: \.isActive) {
            return "Closes in \(SessionPresentation.relativeCountdown(to: activeSession.activeInterval.end, from: now))"
        }

        if let next = nextStartItem(sessionStates: sessionStates, overlapStates: overlapStates) {
            return "\(next.name) starts in \(SessionPresentation.relativeCountdown(to: next.start, from: now))"
        }

        return "Tracking sessions in your local timezone."
    }

    private func activeOverlapName(overlapStates: [OverlapState]) -> String {
        if !SessionPresentation.isForexMarketOpen(at: Date()) {
            return "Closed"
        }

        return overlapStates.first(where: \.isActive)?.definition.shortTitle ?? "None"
    }

    private func nextStartCountdown(sessionStates: [SessionState], overlapStates: [OverlapState], now: Date) -> String {
        guard let next = nextStartItem(sessionStates: sessionStates, overlapStates: overlapStates) else {
            return "—"
        }

        return SessionPresentation.relativeCountdown(to: next.start, from: now)
    }

    private func nextStartItem(sessionStates: [SessionState], overlapStates: [OverlapState]) -> (name: String, start: Date)? {
        let sessionItem = sessionStates.map { (name: $0.definition.shortTitle, start: $0.nextOpenDate) }.min { $0.start < $1.start }
        let overlapItem = overlapStates.map { (name: $0.definition.shortTitle, start: $0.nextStartDate) }.min { $0.start < $1.start }

        switch (sessionItem, overlapItem) {
        case let (session?, overlap?):
            return session.start <= overlap.start ? session : overlap
        case let (session?, nil):
            return session
        case let (nil, overlap?):
            return overlap
        case (nil, nil):
            return nil
        }
    }

    private var localTimeZoneLabel: String {
        TimeZone.current.localizedName(for: .shortStandard, locale: .current) ?? TimeZone.current.identifier
    }

    private func sessionNotificationBinding(for definition: ForexSessionDefinition) -> Binding<Bool> {
        Binding(
            get: {
                switch definition {
                case .asian:
                    preferences.asianSessionNotificationsEnabled
                case .london:
                    preferences.londonSessionNotificationsEnabled
                case .newYork:
                    preferences.newYorkSessionNotificationsEnabled
                }
            },
            set: { isEnabled in
                switch definition {
                case .asian:
                    preferences.asianSessionNotificationsEnabled = isEnabled
                case .london:
                    preferences.londonSessionNotificationsEnabled = isEnabled
                case .newYork:
                    preferences.newYorkSessionNotificationsEnabled = isEnabled
                }

                Task {
                    TickrHaptics.selection()
                    await syncSessionNotification(for: definition, enabled: isEnabled)
                }
            }
        )
    }

    private func overlapNotificationBinding(for definition: ForexOverlapDefinition) -> Binding<Bool> {
        Binding(
            get: {
                switch definition {
                case .asianLondon:
                    preferences.asianLondonOverlapNotificationsEnabled
                case .londonNewYork:
                    preferences.londonNewYorkOverlapNotificationsEnabled
                }
            },
            set: { isEnabled in
                switch definition {
                case .asianLondon:
                    preferences.asianLondonOverlapNotificationsEnabled = isEnabled
                case .londonNewYork:
                    preferences.londonNewYorkOverlapNotificationsEnabled = isEnabled
                }

                Task {
                    TickrHaptics.selection()
                    await syncOverlapNotification(for: definition, enabled: isEnabled)
                }
            }
        )
    }

    private func syncSessionNotification(for definition: ForexSessionDefinition, enabled: Bool) async {
        do {
            if enabled {
                try await SessionNotificationStore.scheduleSessionNotification(for: definition, preferences: preferences)
                notificationMessage = "\(definition.title) session notification scheduled."
            } else {
                await SessionNotificationStore.removeSessionNotification(for: definition)
                notificationMessage = "\(definition.title) session notification removed."
            }
        } catch {
            if enabled {
                setSessionNotification(definition, enabled: false)
            }
            notificationMessage = error.localizedDescription
        }
    }

    private func syncOverlapNotification(for definition: ForexOverlapDefinition, enabled: Bool) async {
        do {
            if enabled {
                try await SessionNotificationStore.scheduleOverlapNotification(for: definition, preferences: preferences)
                notificationMessage = "\(definition.title) notification scheduled."
            } else {
                await SessionNotificationStore.removeOverlapNotification(for: definition)
                notificationMessage = "\(definition.title) notification removed."
            }
        } catch {
            if enabled {
                setOverlapNotification(definition, enabled: false)
            }
            notificationMessage = error.localizedDescription
        }
    }

    private var notificationAlertBinding: Binding<Bool> {
        Binding(
            get: { notificationMessage != nil },
            set: { isPresented in
                if !isPresented {
                    notificationMessage = nil
                }
            }
        )
    }

    private func setSessionNotification(_ definition: ForexSessionDefinition, enabled: Bool) {
        switch definition {
        case .asian:
            preferences.asianSessionNotificationsEnabled = enabled
        case .london:
            preferences.londonSessionNotificationsEnabled = enabled
        case .newYork:
            preferences.newYorkSessionNotificationsEnabled = enabled
        }
    }

    private func setOverlapNotification(_ definition: ForexOverlapDefinition, enabled: Bool) {
        switch definition {
        case .asianLondon:
            preferences.asianLondonOverlapNotificationsEnabled = enabled
        case .londonNewYork:
            preferences.londonNewYorkOverlapNotificationsEnabled = enabled
        }
    }
}

private struct SessionTimelineView: View {
    let sessionStates: [SessionState]

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width - 32

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(TickrPalette.surfaceStrong)

                VStack(spacing: 14) {
                    HStack {
                        ForEach([0, 6, 12, 18, 24], id: \.self) { hour in
                            Text(hour == 24 ? "24" : "\(hour)")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(TickrPalette.muted)
                                .frame(maxWidth: .infinity, alignment: hour == 0 ? .leading : .center)
                        }
                    }

                    ForEach(sessionStates) { state in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(state.definition.shortTitle)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(TickrPalette.text)
                                Spacer()
                                Text(state.localWindowLabel)
                                    .font(.caption2)
                                    .foregroundStyle(TickrPalette.muted)
                            }

                            ZStack(alignment: .leading) {
                                Capsule(style: .continuous)
                                    .fill(TickrPalette.surface)
                                    .frame(height: 18)

                                ForEach(Array(state.timelineSegments.enumerated()), id: \.offset) { _, segment in
                                    Capsule(style: .continuous)
                                        .fill(state.definition.color.opacity(state.isActive ? 1 : 0.55))
                                        .frame(width: width * CGFloat(segment.length), height: 18)
                                        .offset(x: 16 + width * CGFloat(segment.start))
                                }
                            }
                        }
                    }
                }
                .padding(16)
            }
        }
    }
}

enum ForexSessionDefinition: CaseIterable, Identifiable {
    case asian
    case london
    case newYork

    var id: String { shortTitle }

    var title: String {
        switch self {
        case .asian:
            "Sydney/Tokyo"
        case .london:
            "London"
        case .newYork:
            "New York"
        }
    }

    var shortTitle: String {
        switch self {
        case .asian:
            "Asian"
        case .london:
            "London"
        case .newYork:
            "New York"
        }
    }

    var startTimeZone: TimeZone {
        switch self {
        case .asian:
            TimeZone(identifier: "Australia/Sydney") ?? .current
        case .london:
            TimeZone(identifier: "Europe/London") ?? .current
        case .newYork:
            TimeZone(identifier: "America/New_York") ?? .current
        }
    }

    var endTimeZone: TimeZone {
        switch self {
        case .asian:
            TimeZone(identifier: "Asia/Tokyo") ?? .current
        case .london:
            TimeZone(identifier: "Europe/London") ?? .current
        case .newYork:
            TimeZone(identifier: "America/New_York") ?? .current
        }
    }

    var startHour: Int {
        switch self {
        case .asian: 7
        case .london: 8
        case .newYork: 8
        }
    }

    var startMinute: Int { 0 }

    var endHour: Int {
        switch self {
        case .asian: 18
        case .london: 17
        case .newYork: 17
        }
    }

    var endMinute: Int { 0 }

    var color: Color {
        switch self {
        case .asian:
            Color(red: 0.15, green: 0.49, blue: 0.69)
        case .london:
            TickrPalette.accent
        case .newYork:
            Color(red: 0.72, green: 0.32, blue: 0.20)
        }
    }
}

private struct SessionState: Identifiable {
    let definition: ForexSessionDefinition
    let activeInterval: DateInterval
    let nextOpenDate: Date
    let isActive: Bool
    let timelineSegments: [TimelineSegment]
    let localWindowLabel: String
    let openRelativeLabel: String
    let closeRelativeLabel: String

    var id: String { definition.id }

    init(definition: ForexSessionDefinition, now: Date) {
        self.definition = definition

        let intervals = SessionPresentation.intervalsAroundNow(for: definition, now: now)
        let active = intervals.first(where: { $0.contains(now) })
        let nextOpen = intervals.map(\.start).filter { $0 > now }.min() ?? SessionPresentation.nextInterval(for: definition, after: now).start
        let referenceInterval = active ?? SessionPresentation.nextInterval(for: definition, after: now)

        self.activeInterval = referenceInterval
        self.nextOpenDate = nextOpen
        self.isActive = active != nil
        self.timelineSegments = SessionPresentation.timelineSegments(for: definition, dayContaining: now)
        self.localWindowLabel = SessionPresentation.localWindowLabel(for: definition, referenceDate: now)
        self.openRelativeLabel = SessionPresentation.relativeCountdown(to: nextOpen, from: now)
        self.closeRelativeLabel = SessionPresentation.relativeCountdown(to: referenceInterval.end, from: now)
    }
}

enum ForexOverlapDefinition: CaseIterable, Identifiable {
    case asianLondon
    case londonNewYork

    var id: String { shortTitle }

    var title: String {
        switch self {
        case .asianLondon:
            "Asian/London Overlap"
        case .londonNewYork:
            "London/New York Overlap"
        }
    }

    var shortTitle: String {
        switch self {
        case .asianLondon:
            "Asia/London"
        case .londonNewYork:
            "London/NY"
        }
    }

    var note: String {
        switch self {
        case .asianLondon:
            "Early European liquidity comes online while Asia is still active."
        case .londonNewYork:
            "Highest-volume period for most forex pairs."
        }
    }

    var sessions: (ForexSessionDefinition, ForexSessionDefinition) {
        switch self {
        case .asianLondon:
            (.asian, .london)
        case .londonNewYork:
            (.london, .newYork)
        }
    }

    var color: Color {
        switch self {
        case .asianLondon:
            Color(red: 0.31, green: 0.55, blue: 0.73)
        case .londonNewYork:
            Color(red: 0.87, green: 0.58, blue: 0.15)
        }
    }
}

private struct OverlapState: Identifiable {
    let definition: ForexOverlapDefinition
    let activeInterval: DateInterval
    let nextStartDate: Date
    let isActive: Bool
    let localWindowLabel: String
    let startRelativeLabel: String
    let endRelativeLabel: String

    var id: String { definition.id }

    init(definition: ForexOverlapDefinition, now: Date) {
        self.definition = definition
        let intervals = SessionPresentation.overlapIntervalsAroundNow(for: definition, now: now)
        let active = intervals.first(where: { $0.contains(now) })
        let nextStart = intervals.map(\.start).filter { $0 > now }.min() ?? SessionPresentation.nextOverlapInterval(for: definition, after: now).start
        let referenceInterval = active ?? SessionPresentation.nextOverlapInterval(for: definition, after: now)

        self.activeInterval = referenceInterval
        self.nextStartDate = nextStart
        self.isActive = active != nil
        self.localWindowLabel = SessionPresentation.localWindowLabel(for: definition, referenceDate: now)
        self.startRelativeLabel = SessionPresentation.relativeCountdown(to: nextStart, from: now)
        self.endRelativeLabel = SessionPresentation.relativeCountdown(to: referenceInterval.end, from: now)
    }
}

private enum SessionPresentation {
    static let newYorkTimeZone = TimeZone(identifier: "America/New_York") ?? .current

    static let utcCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        return calendar
    }()

    static let newYorkCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = newYorkTimeZone
        return calendar
    }()

    static let localCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        return calendar
    }()

    static func intervalsAroundNow(for definition: ForexSessionDefinition, now: Date) -> [DateInterval] {
        (-2...3).compactMap { sessionInterval(for: definition, around: now, dayOffset: $0) }
            .filter { $0.end > now.addingTimeInterval(-24 * 60 * 60) }
            .sorted { $0.start < $1.start }
    }

    static func nextInterval(for definition: ForexSessionDefinition, after date: Date) -> DateInterval {
        intervalsAroundNow(for: definition, now: date)
            .first(where: { $0.start > date })
            ?? sessionInterval(for: definition, around: date, dayOffset: 4)
            ?? DateInterval(start: date, duration: 60)
    }

    static func overlapIntervalsAroundNow(for definition: ForexOverlapDefinition, now: Date) -> [DateInterval] {
        let firstSession = intervalsAroundNow(for: definition.sessions.0, now: now)
        let secondSession = intervalsAroundNow(for: definition.sessions.1, now: now)

        let overlaps = firstSession.flatMap { first in
            secondSession.compactMap { second in
                first.intersection(with: second)
            }
        }

        return overlaps
            .filter { $0.duration > 0 }
            .sorted { $0.start < $1.start }
    }

    static func nextOverlapInterval(for definition: ForexOverlapDefinition, after date: Date) -> DateInterval {
        overlapIntervalsAroundNow(for: definition, now: date)
            .first(where: { $0.start > date })
            ?? DateInterval(start: nextForexMarketOpen(after: date), duration: 60)
    }

    static func isForexMarketOpen(at date: Date) -> Bool {
        let components = newYorkCalendar.dateComponents([.weekday, .hour, .minute], from: date)
        let weekday = components.weekday ?? 1
        let minutes = (components.hour ?? 0) * 60 + (components.minute ?? 0)

        if weekday == 6 {
            return minutes < 17 * 60
        }

        if weekday == 7 {
            return false
        }

        if weekday == 1 {
            return minutes >= 17 * 60
        }

        return true
    }

    static func nextForexMarketOpen(after date: Date) -> Date {
        if isForexMarketOpen(at: date) {
            return date
        }

        let components = newYorkCalendar.dateComponents([.weekday], from: date)
        let weekday = components.weekday ?? 1
        let startOfDay = newYorkCalendar.startOfDay(for: date)

        switch weekday {
        case 6:
            let sunday = newYorkCalendar.date(byAdding: .day, value: 2, to: startOfDay) ?? startOfDay
            return newYorkCalendar.date(bySettingHour: 17, minute: 0, second: 0, of: sunday) ?? date
        case 7:
            let sunday = startOfDay
            return newYorkCalendar.date(bySettingHour: 17, minute: 0, second: 0, of: sunday) ?? date
        case 1:
            return newYorkCalendar.date(bySettingHour: 17, minute: 0, second: 0, of: startOfDay) ?? date
        default:
            return date
        }
    }

    static func localWindowLabel(for definition: ForexSessionDefinition, referenceDate: Date) -> String {
        let interval = nextRelevantInterval(for: definition, referenceDate: referenceDate)
        return "\(localTime(interval.start)) - \(localTime(interval.end))"
    }

    static func localWindowLabel(for definition: ForexOverlapDefinition, referenceDate: Date) -> String {
        let interval = overlapIntervalsAroundNow(for: definition, now: referenceDate).first(where: { $0.contains(referenceDate) || $0.start > referenceDate })
            ?? nextOverlapInterval(for: definition, after: referenceDate)
        return "\(localTime(interval.start)) - \(localTime(interval.end))"
    }

    static func timelineSegments(for definition: ForexSessionDefinition, dayContaining date: Date) -> [TimelineSegment] {
        let localDayStart = localCalendar.startOfDay(for: date)
        let localDayEnd = localCalendar.date(byAdding: .day, value: 1, to: localDayStart) ?? localDayStart
        let localDayInterval = DateInterval(start: localDayStart, end: localDayEnd)

        return intervalsAroundNow(for: definition, now: date).compactMap { interval in
            guard let intersection = interval.intersection(with: localDayInterval) else {
                return nil
            }

            let startFraction = intersection.start.timeIntervalSince(localDayStart) / (24 * 60 * 60)
            let lengthFraction = intersection.duration / (24 * 60 * 60)
            return TimelineSegment(start: startFraction, length: lengthFraction)
        }
    }

    static func relativeCountdown(to date: Date, from now: Date) -> String {
        let seconds = max(Int(date.timeIntervalSince(now)), 0)
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        if hours == 0 {
            return "\(minutes)m"
        }
        return "\(hours)h \(minutes)m"
    }

    private static func localTime(_ date: Date) -> String {
        EventDateFormatter.timeString(from: date, useUTC: false, use24HourTime: false)
    }

    private static func nextRelevantInterval(for definition: ForexSessionDefinition, referenceDate: Date) -> DateInterval {
        intervalsAroundNow(for: definition, now: referenceDate)
            .first(where: { $0.contains(referenceDate) || $0.start > referenceDate })
            ?? nextInterval(for: definition, after: referenceDate)
    }

    private static func sessionInterval(for definition: ForexSessionDefinition, around date: Date, dayOffset: Int) -> DateInterval? {
        guard
            let start = zonedDate(
                in: definition.startTimeZone,
                relativeTo: date,
                dayOffset: dayOffset,
                hour: definition.startHour,
                minute: definition.startMinute
            ),
            var end = zonedDate(
                in: definition.endTimeZone,
                relativeTo: date,
                dayOffset: dayOffset,
                hour: definition.endHour,
                minute: definition.endMinute
            )
        else {
            return nil
        }

        if end <= start {
            end = Calendar(identifier: .gregorian).date(byAdding: .day, value: 1, to: end) ?? end
        }

        let interval = DateInterval(start: start, end: end)
        return clipToForexWeek(interval)
    }

    private static func zonedDate(in timeZone: TimeZone, relativeTo date: Date, dayOffset: Int, hour: Int, minute: Int) -> Date? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let startOfDay = calendar.startOfDay(for: date)
        guard let shiftedDay = calendar.date(byAdding: .day, value: dayOffset, to: startOfDay) else {
            return nil
        }

        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: shiftedDay)
    }

    private static func clipToForexWeek(_ interval: DateInterval) -> DateInterval? {
        let openIntervals = forexOpenIntervals(around: interval.start)
        for openInterval in openIntervals {
            if let intersection = interval.intersection(with: openInterval), intersection.duration > 0 {
                return intersection
            }
        }

        return nil
    }

    private static func forexOpenIntervals(around date: Date) -> [DateInterval] {
        (-1...2).compactMap { weekOffset in
            let weekStart = startOfWeekInNewYork(for: date, weekOffset: weekOffset)
            guard
                let sundayOpen = newYorkCalendar.date(bySettingHour: 17, minute: 0, second: 0, of: weekStart),
                let fridayClose = newYorkCalendar.date(byAdding: .day, value: 5, to: sundayOpen)
            else {
                return nil
            }

            return DateInterval(start: sundayOpen, end: fridayClose)
        }
    }

    private static func startOfWeekInNewYork(for date: Date, weekOffset: Int) -> Date {
        let dayStart = newYorkCalendar.startOfDay(for: date)
        let weekday = newYorkCalendar.component(.weekday, from: dayStart)
        let daysToSunday = weekday - 1
        let currentSunday = newYorkCalendar.date(byAdding: .day, value: -daysToSunday, to: dayStart) ?? dayStart
        return newYorkCalendar.date(byAdding: .day, value: weekOffset * 7, to: currentSunday) ?? currentSunday
    }
}

private struct TimelineSegment {
    let start: Double
    let length: Double
}

enum SessionNotificationStore {
    private static let prefix = "tickr.sessions."

    static func resyncEnabledNotifications(preferences: UserPreferences) async {
        let existingIdentifiers = await pendingIdentifiers()
        let sessionIdentifiers = existingIdentifiers.filter { $0.hasPrefix(prefix) }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: sessionIdentifiers)

        if preferences.asianSessionNotificationsEnabled {
            try? await scheduleSessionNotification(for: .asian, preferences: preferences)
        }
        if preferences.londonSessionNotificationsEnabled {
            try? await scheduleSessionNotification(for: .london, preferences: preferences)
        }
        if preferences.newYorkSessionNotificationsEnabled {
            try? await scheduleSessionNotification(for: .newYork, preferences: preferences)
        }
        if preferences.asianLondonOverlapNotificationsEnabled {
            try? await scheduleOverlapNotification(for: .asianLondon, preferences: preferences)
        }
        if preferences.londonNewYorkOverlapNotificationsEnabled {
            try? await scheduleOverlapNotification(for: .londonNewYork, preferences: preferences)
        }
    }

    static func scheduleSessionNotification(for definition: ForexSessionDefinition, preferences: UserPreferences) async throws {
        let nextStart = SessionPresentation.nextInterval(for: definition, after: Date()).start
        try await scheduleNotification(
            identifier: prefix + "session." + definition.id,
            title: "\(definition.title) Session",
            body: "\(definition.title) opens in 15 minutes.",
            fireDate: nextStart.addingTimeInterval(-15 * 60),
            preferences: preferences
        )
    }

    static func removeSessionNotification(for definition: ForexSessionDefinition) async {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [prefix + "session." + definition.id])
    }

    static func scheduleOverlapNotification(for definition: ForexOverlapDefinition, preferences: UserPreferences) async throws {
        let nextStart = SessionPresentation.nextOverlapInterval(for: definition, after: Date()).start
        try await scheduleNotification(
            identifier: prefix + "overlap." + definition.id,
            title: definition.title,
            body: "\(definition.title) starts in 15 minutes.",
            fireDate: nextStart.addingTimeInterval(-15 * 60),
            preferences: preferences
        )
    }

    static func removeOverlapNotification(for definition: ForexOverlapDefinition) async {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [prefix + "overlap." + definition.id])
    }

    private static func scheduleNotification(identifier: String, title: String, body: String, fireDate: Date, preferences: UserPreferences) async throws {
        guard fireDate > Date() else {
            throw SessionNotificationError.notificationWindowPassed
        }

        guard !preferences.isWithinQuietHours(on: fireDate) else {
            throw SessionNotificationError.quietHoursBlocked
        }

        let granted = try await requestAuthorization()
        guard granted else {
            throw SessionNotificationError.authorizationDenied
        }

        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = preferences.notificationSoundOption.unNotificationSound

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(fireDate.timeIntervalSinceNow, 1), repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        try await add(request, center: center)
    }

    private static func requestAuthorization() async throws -> Bool {
        try await NotificationAuthorizationStore.requestAuthorizationIfNeeded()
    }

    private static func add(_ request: UNNotificationRequest, center: UNUserNotificationCenter) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            center.add(request) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    private static func pendingIdentifiers() async -> [String] {
        await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
                continuation.resume(returning: requests.map(\.identifier))
            }
        }
    }
}

private enum SessionNotificationError: LocalizedError {
    case authorizationDenied
    case notificationWindowPassed
    case quietHoursBlocked

    var errorDescription: String? {
        switch self {
        case .authorizationDenied:
            "Notifications are disabled for Tickr."
        case .notificationWindowPassed:
            "The next 15-minute warning for that session has already passed."
        case .quietHoursBlocked:
            "That alert falls within your quiet hours."
        }
    }
}

#Preview {
    NavigationStack {
        SessionsKillzonesView(
            viewModel: CalendarViewModel(service: MockCalendarService()),
            preferences: UserPreferences()
        )
    }
}
