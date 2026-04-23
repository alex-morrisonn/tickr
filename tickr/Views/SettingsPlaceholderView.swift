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
                        subtitle: "See the major trading centers in your time zone and what is live right now."
                    )

                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        let sessionStates = sessionDefinitions.map { SessionState(definition: $0, now: context.date) }
                        let overlapStates = overlapDefinitions.map { OverlapState(definition: $0, now: context.date) }

                        VStack(alignment: .leading, spacing: TickrLayout.sectionSpacing) {
                            marketBoardCard(now: context.date)
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

    private func marketBoardCard(now: Date) -> some View {
        TickrCard {
            VStack(alignment: .leading, spacing: 18) {
                boardHeaderText

                MarketBoardPanel(now: now, events: viewModel.events)
            }
        }
        .padding(.top, 8)
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

    private var boardHeaderText: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Market Board")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(TickrPalette.text)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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

#Preview("Sessions") {
    NavigationStack {
        SessionsKillzonesView(
            viewModel: CalendarViewModel(service: MockCalendarService()),
            preferences: UserPreferences()
        )
    }
}

#Preview("Sessions iPad", traits: .fixedLayout(width: 834, height: 1194)) {
    NavigationStack {
        SessionsKillzonesView(
            viewModel: CalendarViewModel(service: MockCalendarService()),
            preferences: UserPreferences()
        )
    }
}

private struct MarketBoardPanel: View {
    let now: Date
    let events: [EconomicEvent]

    @State private var markerDayFractionOverride: Double?
    @State private var markerDragStartFraction: Double?

    private let rows = MarketBoardDefinition.allCases
    private let activityService: any MarketActivityService = EstimatedMarketActivityService()

    var body: some View {
        let displayedDate = markerDayFractionOverride.map { SessionPresentation.date(for: $0, onSameDayAs: now) } ?? now
        let activitySnapshot = activityService.snapshot(at: displayedDate, events: events)

        VStack(alignment: .leading, spacing: 14) {
            GeometryReader { proxy in
                let isCompact = proxy.size.width < 380
                let labelWidth: CGFloat = isCompact ? 92 : 106
                let spacing: CGFloat = isCompact ? 8 : 10
                let rowHeight: CGFloat = isCompact ? 70 : 74
                let volumeRowHeight: CGFloat = isCompact ? 110 : 118
                let timelineWidth = max(proxy.size.width - labelWidth - spacing, 1)
                let compactTimelineWidth = max(proxy.size.width - 32, 1)
                let timelineRowCount = CGFloat(rows.count)
                let markerHeight = isCompact
                    ? proxy.size.height - rowHeight
                    : (rowHeight * timelineRowCount) + (8 * max(timelineRowCount - 1, 0)) + 8 + volumeRowHeight
                let markerFraction = markerDayFractionOverride ?? SessionPresentation.dayFraction(for: now)
                let markerXPosition = (isCompact ? compactTimelineWidth : timelineWidth) * markerFraction

                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(TickrPalette.surfaceStrong)

                    Group {
                        if isCompact {
                            ZStack(alignment: .topLeading) {
                                VStack(spacing: 8) {
                                    ForEach(rows) { definition in
                                        CompactMarketTimelineRow(
                                            state: MarketBoardState(definition: definition, now: displayedDate),
                                            timelineWidth: compactTimelineWidth
                                        )
                                        .frame(height: rowHeight)
                                    }

                                    CompactVolumeTimelineRow(
                                        snapshot: activitySnapshot,
                                        markerDate: displayedDate,
                                        timelineWidth: compactTimelineWidth
                                    )
                                    .frame(height: volumeRowHeight)
                                }

                                SessionNowMarker(
                                    xPosition: markerXPosition,
                                    timelineWidth: compactTimelineWidth,
                                    height: markerHeight,
                                    timeLabel: markerTimeLabel,
                                    isInteracting: markerDayFractionOverride != nil
                                )
                                .gesture(markerDragGesture(timelineWidth: compactTimelineWidth))
                            }
                        } else {
                            HStack(alignment: .top, spacing: spacing) {
                                VStack(spacing: 8) {
                                    ForEach(rows) { definition in
                                        MarketSessionSidebarCard(
                                            state: MarketBoardState(definition: definition, now: displayedDate),
                                            compact: false
                                        )
                                        .frame(height: rowHeight)
                                    }

                                    VolumeSidebarCard(
                                        title: "Volume",
                                        statusText: activitySnapshot.statusText,
                                        tag: activitySnapshot.tier.rawValue,
                                        tagColor: activityColor(for: activitySnapshot.tier)
                                    )
                                    .frame(height: volumeRowHeight)
                                }
                                .frame(width: labelWidth)

                                ZStack(alignment: .topLeading) {
                                    VStack(spacing: 8) {
                                        ForEach(rows) { definition in
                                            MarketSessionTimelineRow(
                                                state: MarketBoardState(definition: definition, now: displayedDate),
                                                timelineWidth: timelineWidth,
                                                compact: false
                                            )
                                            .frame(height: rowHeight)
                                        }

                                        VolumeTimelineRow(
                                            snapshot: activitySnapshot,
                                            markerDate: displayedDate
                                        )
                                            .frame(height: volumeRowHeight)
                                    }

                                    SessionNowMarker(
                                        xPosition: markerXPosition,
                                        timelineWidth: timelineWidth,
                                        height: markerHeight,
                                        timeLabel: markerTimeLabel,
                                        isInteracting: markerDayFractionOverride != nil
                                    )
                                    .gesture(markerDragGesture(timelineWidth: timelineWidth))
                                }
                                .frame(width: timelineWidth)
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                }
            }
            .frame(height: 458)
        }
    }

    private var markerTimeLabel: String {
        let displayedDate = markerDayFractionOverride.map { SessionPresentation.date(for: $0, onSameDayAs: now) } ?? now
        return SessionPresentation.markerTimeString(for: displayedDate)
    }

    private func markerDragGesture(timelineWidth: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let clampedTimelineWidth = max(timelineWidth, 1)
                let startFraction = markerDragStartFraction
                    ?? markerDayFractionOverride
                    ?? SessionPresentation.dayFraction(for: now)

                if markerDragStartFraction == nil {
                    markerDragStartFraction = startFraction
                }

                let translatedFraction = startFraction + (value.translation.width / clampedTimelineWidth)
                let fraction = snappedMarkerFraction(for: translatedFraction, timelineWidth: clampedTimelineWidth)
                markerDayFractionOverride = fraction
            }
            .onEnded { _ in
                markerDragStartFraction = nil
                markerDayFractionOverride = nil
            }
    }

    private func snappedMarkerFraction(for fraction: Double, timelineWidth: CGFloat) -> Double {
        let clampedFraction = min(max(fraction, 0), 1)
        let snapThreshold = 4 / timelineWidth
        let snapFractions = SessionPresentation.marketBoundaryFractions(onSameDayAs: now)

        guard let nearestBoundary = snapFractions.min(by: {
            abs($0 - clampedFraction) < abs($1 - clampedFraction)
        }) else {
            return clampedFraction
        }

        return abs(nearestBoundary - clampedFraction) <= snapThreshold ? nearestBoundary : clampedFraction
    }
    private func activityColor(for tier: MarketActivityTier) -> Color {
        switch tier {
        case .high:
            TickrPalette.success
        case .medium:
            TickrPalette.warning
        case .low:
            Color(red: 0.80, green: 0.26, blue: 0.47)
        }
    }
}

enum MarketBoardDefinition: CaseIterable, Identifiable {
    case sydney
    case tokyo
    case london
    case newYork

    var id: String { cityName }

    var cityName: String {
        switch self {
        case .sydney:
            "Sydney"
        case .tokyo:
            "Tokyo"
        case .london:
            "London"
        case .newYork:
            "New York"
        }
    }

    var flag: String {
        switch self {
        case .sydney:
            "🇦🇺"
        case .tokyo:
            "🇯🇵"
        case .london:
            "🇬🇧"
        case .newYork:
            "🇺🇸"
        }
    }

    var timeZone: TimeZone {
        switch self {
        case .sydney:
            TimeZone(identifier: "Australia/Sydney") ?? .current
        case .tokyo:
            TimeZone(identifier: "Asia/Tokyo") ?? .current
        case .london:
            TimeZone(identifier: "Europe/London") ?? .current
        case .newYork:
            TimeZone(identifier: "America/New_York") ?? .current
        }
    }

    var openHour: Int {
        switch self {
        case .sydney:
            7
        case .tokyo:
            9
        case .london:
            8
        case .newYork:
            8
        }
    }

    var closeHour: Int {
        switch self {
        case .sydney:
            16
        case .tokyo:
            18
        case .london:
            17
        case .newYork:
            17
        }
    }

    var color: Color {
        switch self {
        case .sydney:
            Color(red: 0.26, green: 0.39, blue: 0.83)
        case .tokyo:
            Color(red: 0.64, green: 0.13, blue: 0.57)
        case .london:
            Color(red: 0.27, green: 0.54, blue: 0.89)
        case .newYork:
            Color(red: 0.43, green: 0.78, blue: 0.22)
        }
    }

}

private struct MarketBoardState: Identifiable {
    let definition: MarketBoardDefinition
    let localNow: String
    let localDateLine: String
    let nextTransitionLabel: String
    let transitionStatusText: String
    let transitionStatusColor: Color
    let timelineSegments: [TimelineSegment]

    var id: String { definition.id }

    init(definition: MarketBoardDefinition, now: Date) {
        self.definition = definition

        let intervals = SessionPresentation.marketIntervalsAroundNow(for: definition, now: now)
        let active = intervals.first(where: { $0.contains(now) })
        let nextInterval = intervals.first(where: { $0.start > now }) ?? SessionPresentation.nextMarketInterval(for: definition, after: now)
        let referenceInterval = active ?? nextInterval

        self.localNow = SessionPresentation.timeString(in: definition.timeZone, for: now)
        self.localDateLine = SessionPresentation.dateString(in: definition.timeZone, for: now)
        self.nextTransitionLabel = active == nil
            ? "Opens in \(SessionPresentation.relativeCountdown(to: referenceInterval.start, from: now))"
            : "Closes in \(SessionPresentation.relativeCountdown(to: referenceInterval.end, from: now))"
        self.transitionStatusText = active == nil ? "Closed" : "Open"
        self.transitionStatusColor = active == nil ? Color.red : TickrPalette.success
        self.timelineSegments = SessionPresentation.timelineSegments(for: definition, dayContaining: now)
    }
}

private struct MarketSessionSidebarCard: View {
    let state: MarketBoardState
    let compact: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text(state.definition.flag)
                    .font(compact ? .subheadline : .headline)

                VStack(alignment: .leading, spacing: 2) {
                    Text(state.definition.cityName)
                        .font(compact ? .caption.weight(.semibold) : .subheadline.weight(.semibold))
                        .foregroundStyle(TickrPalette.text)
                        .lineLimit(1)

                    Text(state.localNow)
                        .font(compact ? .caption.weight(.medium) : .subheadline.weight(.medium))
                        .foregroundStyle(TickrPalette.muted)
                        .lineLimit(1)
                }

                Spacer(minLength: 6)

                Text(state.transitionStatusText)
                    .font((compact ? Font.caption2 : Font.caption).weight(.semibold))
                    .foregroundStyle(state.transitionStatusColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            Text(state.localDateLine)
                .font(.caption2)
                .foregroundStyle(TickrPalette.muted)
                .lineLimit(1)
        }
        .padding(.horizontal, compact ? 8 : 10)
        .padding(.vertical, compact ? 8 : 9)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(TickrPalette.surface)
        )
    }
}

private struct MarketSessionTimelineRow: View {
    let state: MarketBoardState
    let timelineWidth: CGFloat
    let compact: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.12))

            VStack(alignment: .leading, spacing: 8) {
                ZStack(alignment: .leading) {
                    Capsule(style: .continuous)
                        .fill(TickrPalette.surface)
                        .frame(height: compact ? 8 : 10)

                    ForEach(Array(state.timelineSegments.enumerated()), id: \.offset) { _, segment in
                        Capsule(style: .continuous)
                            .fill(state.definition.color)
                            .frame(width: max(timelineWidth * segment.length, 10), height: compact ? 8 : 10)
                            .offset(x: timelineWidth * segment.start)
                    }
                }
                .frame(height: compact ? 8 : 10)

                Text(state.nextTransitionLabel)
                    .font((compact ? Font.caption2 : Font.caption).weight(.semibold))
                    .foregroundStyle(TickrPalette.muted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .padding(.horizontal, compact ? 8 : 10)
            .padding(.vertical, compact ? 8 : 9)
        }
    }
}

private struct CompactMarketTimelineRow: View {
    let state: MarketBoardState
    let timelineWidth: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(state.definition.flag)
                    .font(.caption)

                Text(state.definition.cityName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(TickrPalette.text)
                    .lineLimit(1)

                Text(state.localNow)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(TickrPalette.muted)
                    .lineLimit(1)

                Spacer(minLength: 4)

                Text(state.transitionStatusText)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(state.transitionStatusColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            VStack(alignment: .leading, spacing: 4) {
                ZStack(alignment: .leading) {
                    Capsule(style: .continuous)
                        .fill(TickrPalette.surface)
                        .frame(height: 8)

                    ForEach(Array(state.timelineSegments.enumerated()), id: \.offset) { _, segment in
                        Capsule(style: .continuous)
                            .fill(state.definition.color)
                            .frame(width: max(timelineWidth * segment.length, 10), height: 8)
                            .offset(x: timelineWidth * segment.start)
                    }
                }
                .frame(height: 8)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.12))
        )
    }
}

private struct VolumeSidebarCard: View {
    let title: String
    let statusText: String
    let tag: String
    let tagColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(TickrPalette.text)

            Text(statusText)
                .font(.caption.weight(.medium))
                .foregroundStyle(TickrPalette.muted)
                .lineLimit(1)

            TickrPill(text: tag, tint: tagColor.opacity(0.14))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(TickrPalette.surface)
        )
    }
}

private struct VolumeTimelineRow: View {
    let snapshot: MarketActivitySnapshot
    let markerDate: Date

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.12))

            VolumeProfileWave(snapshot: snapshot, markerDate: markerDate, showsBackground: false)
                .padding(.horizontal, 10)
                .padding(.vertical, 12)
        }
    }
}

private struct CompactVolumeTimelineRow: View {
    let snapshot: MarketActivitySnapshot
    let markerDate: Date
    let timelineWidth: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("Trading volume")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(TickrPalette.text)

                Text(snapshot.statusText)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(TickrPalette.muted)

                Spacer(minLength: 4)

                TickrPill(text: snapshot.tier.rawValue, tint: activityColor.opacity(0.14))
            }

            VolumeProfileWave(snapshot: snapshot, markerDate: markerDate, showsBackground: false)
                .frame(width: timelineWidth, height: 62)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.12))
        )
    }

    private var activityColor: Color {
        switch snapshot.tier {
        case .high:
            TickrPalette.success
        case .medium:
            TickrPalette.warning
        case .low:
            Color(red: 0.80, green: 0.26, blue: 0.47)
        }
    }
}

private struct SessionNowMarker: View {
    let xPosition: CGFloat
    let timelineWidth: CGFloat
    let height: CGFloat
    let timeLabel: String
    let isInteracting: Bool

    private let markerWidth: CGFloat = 78
    private let lineWidth: CGFloat = 3

    var body: some View {
        let clampedXPosition = min(max(xPosition, 0), timelineWidth)

        return ZStack(alignment: .topLeading) {
            ZStack(alignment: .top) {
                if isInteracting {
                    Text(timeLabel)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(TickrPalette.text)
                        .fixedSize()
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule(style: .continuous)
                                .fill(TickrPalette.surface)
                        )
                        .offset(y: -34)
                }

                VStack(spacing: 0) {
                    Image(systemName: "triangle.fill")
                        .font(.caption)
                        .foregroundStyle(TickrPalette.accent)
                        .rotationEffect(.degrees(180))
                        .offset(y: -1)

                    Rectangle()
                        .fill(TickrPalette.accent)
                        .frame(width: lineWidth, height: max(height + 12, 1))
                        .shadow(color: TickrPalette.accent.opacity(0.2), radius: 6, x: 0, y: 0)
                }
            }
            .frame(width: markerWidth)
            .offset(x: clampedXPosition - (markerWidth / 2))
        }
        .frame(width: timelineWidth, alignment: .topLeading)
        .contentShape(Rectangle())
    }
}

private struct VolumeProfileWave: View {
    let snapshot: MarketActivitySnapshot
    let markerDate: Date
    var showsBackground: Bool = true

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let points = wavePoints(in: size)
            let strokeGradient = LinearGradient(
                colors: [
                    TickrPalette.success,
                    TickrPalette.warning,
                    Color(red: 0.80, green: 0.26, blue: 0.47),
                    TickrPalette.warning,
                    TickrPalette.success
                ],
                startPoint: .leading,
                endPoint: .trailing
            )

            ZStack {
                if showsBackground {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    TickrPalette.surfaceStrong,
                                    TickrPalette.surface
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }

                waveFillPath(points: points, size: size)
                    .fill(
                        LinearGradient(
                            colors: [
                                TickrPalette.success.opacity(0.24),
                                TickrPalette.warning.opacity(0.18),
                                Color(red: 0.80, green: 0.26, blue: 0.47).opacity(0.14),
                                Color.clear
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                waveStrokePath(points: points)
                    .stroke(
                        strokeGradient,
                        style: StrokeStyle(lineWidth: 10, lineCap: .round, lineJoin: .round)
                    )
                    .blur(radius: 14)
                    .opacity(0.28)

                waveStrokePath(points: points)
                    .stroke(
                        strokeGradient,
                        style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round)
                    )
                    .blur(radius: 4)
                    .opacity(0.24)

                waveStrokePath(points: points)
                    .stroke(
                        strokeGradient,
                        style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round)
                    )

            }
        }
    }

    private func waveY(sample: Double, height: CGFloat) -> CGFloat {
        let normalizedValue = emphasizedSample(sample)
        let verticalPadding = height * 0.10
        let drawableHeight = max(height - (verticalPadding * 2), 1)
        return verticalPadding + (1 - normalizedValue) * drawableHeight
    }

    private func wavePoints(in size: CGSize) -> [CGPoint] {
        let samples = snapshot.sparklineSamples
        let count = max(samples.count - 1, 1)

        return samples.enumerated().map { index, sample in
            let progress = Double(index) / Double(count)
            return CGPoint(
                x: size.width * progress,
                y: waveY(sample: sample, height: size.height)
            )
        }
    }

    private func emphasizedSample(_ sample: Double) -> Double {
        let clampedSample = min(max(sample, 0), 1)
        let boostedSample = min(max(0.5 + ((clampedSample - 0.5) * 1.7), 0), 1)

        if boostedSample < 0.5 {
            return 0.5 * pow(boostedSample * 2, 1.45)
        }

        let mirroredSample = (1 - boostedSample) * 2
        return 1 - (0.5 * pow(mirroredSample, 1.45))
    }

    private func waveStrokePath(points: [CGPoint]) -> Path {
        Path { path in
            guard let firstPoint = points.first else {
                return
            }

            path.move(to: firstPoint)

            if points.count == 2, let lastPoint = points.last {
                path.addLine(to: lastPoint)
            } else {
                for index in 1..<points.count {
                    let previousPoint = points[index - 1]
                    let currentPoint = points[index]
                    let midpoint = CGPoint(
                        x: (previousPoint.x + currentPoint.x) / 2,
                        y: (previousPoint.y + currentPoint.y) / 2
                    )

                    path.addQuadCurve(to: midpoint, control: previousPoint)
                    path.addQuadCurve(to: currentPoint, control: midpoint)
                }
            }
        }
    }

    private func waveFillPath(points: [CGPoint], size: CGSize) -> Path {
        var path = waveStrokePath(points: points)

        guard let lastPoint = points.last else {
            return path
        }

        path.addLine(to: CGPoint(x: lastPoint.x, y: size.height))
        path.addLine(to: CGPoint(x: 0, y: size.height))
        path.closeSubpath()

        return path
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

enum SessionPresentation {
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

    static func marketIntervalsAroundNow(for definition: MarketBoardDefinition, now: Date) -> [DateInterval] {
        (-2...3).compactMap { marketInterval(for: definition, around: now, dayOffset: $0) }
            .filter { $0.end > now.addingTimeInterval(-24 * 60 * 60) }
            .sorted { $0.start < $1.start }
    }

    static func nextMarketInterval(for definition: MarketBoardDefinition, after date: Date) -> DateInterval {
        marketIntervalsAroundNow(for: definition, now: date)
            .first(where: { $0.start > date })
            ?? marketInterval(for: definition, around: date, dayOffset: 4)
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
        let localDayInterval = localDayInterval(containing: date)
        let localDayStart = localDayInterval.start
        let localDayDuration = localDayInterval.duration

        return intervalsAroundNow(for: definition, now: date).compactMap { interval in
            guard let intersection = interval.intersection(with: localDayInterval) else {
                return nil
            }

            let startFraction = intersection.start.timeIntervalSince(localDayStart) / localDayDuration
            let lengthFraction = intersection.duration / localDayDuration
            return TimelineSegment(start: startFraction, length: lengthFraction)
        }
    }

    static func timelineSegments(for definition: MarketBoardDefinition, dayContaining date: Date) -> [TimelineSegment] {
        let localDayInterval = localDayInterval(containing: date)
        let localDayStart = localDayInterval.start
        let localDayDuration = localDayInterval.duration

        return marketIntervalsAroundNow(for: definition, now: date).compactMap { interval in
            guard let intersection = interval.intersection(with: localDayInterval) else {
                return nil
            }

            let startFraction = intersection.start.timeIntervalSince(localDayStart) / localDayDuration
            let lengthFraction = intersection.duration / localDayDuration
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

    static func timeString(in timeZone: TimeZone, for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = timeZone
        formatter.dateFormat = "h:mm a"
        formatter.amSymbol = "am"
        formatter.pmSymbol = "pm"
        return formatter.string(from: date)
    }

    static func dateString(in timeZone: TimeZone, for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = timeZone
        formatter.dateFormat = "EEE MMM d"
        return formatter.string(from: date)
    }

    static func zoneLabel(for timeZone: TimeZone) -> String {
        timeZone.localizedName(for: .shortStandard, locale: .current) ?? timeZone.identifier
    }

    static func dayFraction(for date: Date) -> Double {
        let dayInterval = localDayInterval(containing: date)
        let elapsed = date.timeIntervalSince(dayInterval.start)
        return min(max(elapsed / dayInterval.duration, 0), 1)
    }

    static func date(for dayFraction: Double, onSameDayAs referenceDate: Date) -> Date {
        let dayInterval = localDayInterval(containing: referenceDate)
        let clampedFraction = min(max(dayFraction, 0), 1)
        return dayInterval.start.addingTimeInterval(dayInterval.duration * clampedFraction)
    }

    static func markerTimeString(for date: Date) -> String {
        EventDateFormatter.timeString(from: date, useUTC: false, use24HourTime: false)
    }

    static func marketBoundaryFractions(onSameDayAs referenceDate: Date) -> [Double] {
        let localDayInterval = localDayInterval(containing: referenceDate)
        let localDayStart = localDayInterval.start
        let localDayDuration = localDayInterval.duration
        var fractions: [Double] = []

        for definition in MarketBoardDefinition.allCases {
            let intervals = marketIntervalsAroundNow(for: definition, now: referenceDate)
            for interval in intervals {
                let boundaries = [interval.start, interval.end]
                for boundary in boundaries where localDayInterval.contains(boundary) {
                    fractions.append(boundary.timeIntervalSince(localDayStart) / localDayDuration)
                }
            }
        }

        return fractions
    }

    static func hourLabel(for hour: Int) -> String {
        let normalizedHour = hour % 24
        switch normalizedHour {
        case 0:
            return "12"
        case 1...12:
            return "\(normalizedHour)"
        default:
            return "\(normalizedHour - 12)"
        }
    }

    static func currentLocalHour(on date: Date) -> Int {
        localCalendar.component(.hour, from: date)
    }

    private static func localDayInterval(containing date: Date) -> DateInterval {
        localCalendar.dateInterval(of: .day, for: date)
            ?? DateInterval(start: localCalendar.startOfDay(for: date), duration: 24 * 60 * 60)
    }

    private static func localTime(_ date: Date) -> String {
        EventDateFormatter.timeString(from: date, useUTC: false, use24HourTime: false)
    }

    private static func nextRelevantInterval(for definition: ForexSessionDefinition, referenceDate: Date) -> DateInterval {
        intervalsAroundNow(for: definition, now: referenceDate)
            .first(where: { $0.contains(referenceDate) || $0.start > referenceDate })
            ?? nextInterval(for: definition, after: referenceDate)
    }

    private static func marketInterval(for definition: MarketBoardDefinition, around date: Date, dayOffset: Int) -> DateInterval? {
        guard
            let start = zonedDate(
                in: definition.timeZone,
                relativeTo: date,
                dayOffset: dayOffset,
                hour: definition.openHour,
                minute: 0
            ),
            let end = zonedDate(
                in: definition.timeZone,
                relativeTo: date,
                dayOffset: dayOffset,
                hour: definition.closeHour,
                minute: 0
            )
        else {
            return nil
        }

        let interval = DateInterval(start: start, end: max(end, start.addingTimeInterval(60)))
        return clipToForexWeek(interval)
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

struct TimelineSegment {
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
