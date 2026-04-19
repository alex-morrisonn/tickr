import SwiftUI

@MainActor
struct PairsPlaceholderView: View {
    let viewModel: CalendarViewModel
    @Bindable var preferences: UserPreferences

    @State private var selectedPairForDashboard: String?

    private let pairCategories = PairCatalogCategory.allCases

    private var selectedPairs: [String] {
        preferences.watchedPairSymbols.sorted()
    }

    private var selectedPairSummaries: [PairDashboardSummary] {
        selectedPairs.map { symbol in
            PairDashboardSummary(
                symbol: symbol,
                events: viewModel.events(forPair: symbol).sorted { $0.timestamp < $1.timestamp }
            )
        }
    }

    private var highImpactEventsForSelectedPairs: Int {
        Set(selectedPairSummaries.flatMap { summary in
            summary.events.filter { $0.impactLevel == .high }.map(\.id)
        }).count
    }

    private var dashboardPairs: [PairDashboardSummary] {
        if let selectedPairForDashboard {
            return selectedPairSummaries.filter { $0.symbol == selectedPairForDashboard }
        }

        return selectedPairSummaries
    }

    private var dashboardTitle: String {
        if let selectedPairForDashboard {
            return "\(selectedPairForDashboard) Focus"
        }

        return "My Pairs Dashboard"
    }

    private var dashboardSubtitle: String {
        if let selectedPairForDashboard, let summary = selectedPairSummaries.first(where: { $0.symbol == selectedPairForDashboard }) {
            return summary.events.isEmpty
                ? "No scheduled events affecting \(selectedPairForDashboard) this week."
                : "\(summary.events.count) events affecting \(selectedPairForDashboard) this week."
        }

        return "You have \(highImpactEventsForSelectedPairs) high-impact event\(highImpactEventsForSelectedPairs == 1 ? "" : "s") affecting your pairs this week"
    }

    var body: some View {
        ScrollView {
            TickrScreen {
                VStack(alignment: .leading, spacing: TickrLayout.sectionSpacing) {
                    TickrSectionHeader(
                        eyebrow: "Personalisation",
                        title: "My Pairs",
                        subtitle: "Choose your favourite forex pairs and follow only what matters to them."
                    )

                    selectionOverviewCard
                    pairSelectionSection
                    dashboardSection
                }
            }
        }
        .background(Color.clear)
        .overlay {
            if viewModel.isLoading && viewModel.events.isEmpty {
                ProgressView("Loading pairs...")
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(TickrPalette.surfaceStrong)
                            .overlay {
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(TickrPalette.stroke, lineWidth: 1)
                            }
                    )
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Tickr")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(TickrPalette.text)
            }
        }
        .task {
            guard viewModel.events.isEmpty else { return }
            await viewModel.refresh()
        }
        .refreshable {
            await viewModel.refresh()
            TickrHaptics.success()
        }
        .animation(.easeInOut(duration: 0.18), value: selectedPairs)
        .animation(.easeInOut(duration: 0.18), value: dashboardPairs.map(\.id))
    }

    private var selectionOverviewCard: some View {
        TickrCard {
            VStack(alignment: .leading, spacing: 16) {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 12) {
                        overviewText
                        Spacer()
                        TickrPill(text: "\(selectedPairs.count) selected")
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        overviewText
                        TickrPill(text: "\(selectedPairs.count) selected")
                    }
                }

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: TickrLayout.compactItemSpacing) {
                        TickrMetricCard(title: "Selected", value: "\(selectedPairs.count)")
                        TickrMetricCard(title: "High impact", value: "\(highImpactEventsForSelectedPairs)")
                        TickrMetricCard(title: "This week", value: "\(selectedPairSummaries.flatMap(\.events).count)")
                    }

                    VStack(spacing: TickrLayout.compactItemSpacing) {
                        TickrMetricCard(title: "Selected", value: "\(selectedPairs.count)")
                        TickrMetricCard(title: "High impact", value: "\(highImpactEventsForSelectedPairs)")
                        TickrMetricCard(title: "This week", value: "\(selectedPairSummaries.flatMap(\.events).count)")
                    }
                }
            }
        }
    }

    private var overviewText: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Build your forex watchlist")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(TickrPalette.text)

            Text("Pick the forex pairs you trade most. Tickr will use them to prioritize the events you actually care about.")
                .font(.subheadline)
                .foregroundStyle(TickrPalette.muted)
        }
    }

    private var pairSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Pair Selection")
                    .font(.headline)
                    .foregroundStyle(TickrPalette.text)

                Spacer()

                if !selectedPairs.isEmpty {
                    Button("Clear all") {
                        preferences.watchedPairSymbols = []
                        selectedPairForDashboard = nil
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(TickrPalette.accent)
                }
            }

            ForEach(pairCategories) { category in
                TickrCard {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text(category.title)
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(TickrPalette.text)

                            Spacer()

                            TickrPill(text: "\(category.pairs.count) pairs")
                        }

                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 10)], alignment: .leading, spacing: 10) {
                            ForEach(category.pairs) { pair in
                                Button {
                                    togglePairSelection(pair.symbol)
                                } label: {
                                    PairSelectionChip(
                                        pair: pair,
                                        isSelected: preferences.isPairWatched(pair.symbol),
                                        hasEvents: !viewModel.events(forPair: pair.symbol).isEmpty
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
        }
    }

    private var dashboardSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(dashboardTitle)
                        .font(.headline)
                        .foregroundStyle(TickrPalette.text)
                    Text(dashboardSubtitle)
                        .font(.subheadline)
                        .foregroundStyle(TickrPalette.muted)
                }

                Spacer()

                if selectedPairForDashboard != nil {
                    Button("Show all") {
                        selectedPairForDashboard = nil
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(TickrPalette.accent)
                }
            }

            if selectedPairs.isEmpty {
                TickrCard {
                    Text("Select the pairs you trade to build your personalized calendar.")
                        .font(.subheadline)
                        .foregroundStyle(TickrPalette.muted)
                }
            } else {
                ForEach(dashboardPairs) { summary in
                    NavigationLink {
                        PairEventsView(summary: summary, preferences: preferences)
                    } label: {
                        PairDashboardCard(
                            summary: summary,
                            preferences: preferences,
                            isFocused: selectedPairForDashboard == summary.symbol
                        ) {
                            selectedPairForDashboard = summary.symbol
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func togglePairSelection(_ symbol: String) {
        if preferences.isPairWatched(symbol) {
            preferences.toggleWatch(for: symbol)
            TickrHaptics.selection()

            if selectedPairForDashboard == symbol {
                selectedPairForDashboard = nil
            }
            return
        }

        preferences.toggleWatch(for: symbol)
        TickrHaptics.selection()
    }
}

struct PairSelectionChip: View {
    let pair: PairCatalogPair
    let isSelected: Bool
    let hasEvents: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(pair.symbol)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isSelected ? Color.white : TickrPalette.text)

                Spacer(minLength: 8)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(isSelected ? Color.white : TickrPalette.muted)
            }

            Text(pair.description)
                .font(.caption)
                .foregroundStyle(isSelected ? Color.white.opacity(0.84) : TickrPalette.muted)
                .lineLimit(1)

            if hasEvents {
                Text("This week")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(isSelected ? Color.white.opacity(0.84) : TickrPalette.accent)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 84, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(isSelected ? TickrPalette.accent : TickrPalette.surfaceStrong)
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(TickrPalette.stroke, lineWidth: isSelected ? 0 : 1)
                }
        )
    }
}

private struct PairDashboardCard: View {
    let summary: PairDashboardSummary
    let preferences: UserPreferences
    let isFocused: Bool
    let onFocus: () -> Void

    var body: some View {
        TickrCard {
            VStack(alignment: .leading, spacing: 14) {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 12) {
                        headerText
                        Spacer()
                        focusButton
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        headerText
                        focusButton
                    }
                }

                if summary.events.isEmpty {
                    Text("No scheduled events affecting this pair this week.")
                        .font(.subheadline)
                        .foregroundStyle(TickrPalette.muted)
                } else {
                    VStack(spacing: 10) {
                        ForEach(summary.upcomingEvents.prefix(3)) { event in
                            HStack(alignment: .top, spacing: 12) {
                                Circle()
                                    .fill(event.impactLevel.color)
                                    .frame(width: 10, height: 10)
                                    .padding(.top, 5)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(event.title)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(TickrPalette.text)

                                    Text(eventMetadata(for: event, preferences: preferences))
                                        .font(.caption)
                                        .foregroundStyle(TickrPalette.muted)
                                }

                                Spacer(minLength: 8)

                                Text(EventDateFormatter.timeString(
                                    from: event.timestamp,
                                    useUTC: false,
                                    use24HourTime: preferences.use24HourTime
                                ))
                                .font(.caption.monospacedDigit().weight(.semibold))
                                .foregroundStyle(TickrPalette.muted)
                            }
                        }
                    }
                }
            }
        }
    }

    private var headerText: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(summary.symbol)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(TickrPalette.text)

                TickrPill(text: "\(summary.highImpactCount) high impact", tint: TickrPalette.accentSoft.opacity(0.45))
            }

            Text(summary.events.isEmpty ? "No events this week" : "\(summary.events.count) scheduled events this week")
                .font(.subheadline)
                .foregroundStyle(TickrPalette.muted)
        }
    }

    private var focusButton: some View {
        Button(isFocused ? "Focused" : "Show only this pair") {
            onFocus()
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(isFocused ? Color.white : TickrPalette.text)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule(style: .continuous)
                .fill(isFocused ? TickrPalette.accent : TickrPalette.surfaceStrong)
                .overlay {
                    Capsule(style: .continuous)
                        .stroke(TickrPalette.stroke, lineWidth: isFocused ? 0 : 1)
                }
        )
    }

    private func eventMetadata(for event: EconomicEvent, preferences: UserPreferences) -> String {
        let day = EventDateFormatter.dayString(from: event.timestamp, useUTC: false)
        let category = EventPresentation.categoryLabel(for: event.category)
        return "\(day) • \(category) • \(event.currencyCode)"
    }
}

private struct PairEventsView: View {
    let summary: PairDashboardSummary
    let preferences: UserPreferences

    var body: some View {
        ScrollView {
            TickrScreen {
                VStack(alignment: .leading, spacing: TickrLayout.sectionSpacing) {
                    TickrSectionHeader(
                        eyebrow: "Pair Focus",
                        title: summary.symbol,
                        subtitle: "\(summary.highImpactCount) high-impact event\(summary.highImpactCount == 1 ? "" : "s") this week"
                    )

                    TickrCard {
                        ViewThatFits(in: .horizontal) {
                            HStack(spacing: TickrLayout.compactItemSpacing) {
                                TickrMetricCard(title: "Upcoming", value: "\(summary.upcomingEvents.count)")
                                TickrMetricCard(title: "High impact", value: "\(summary.highImpactCount)")
                                TickrMetricCard(title: "This week", value: "\(summary.events.count)")
                            }

                            VStack(spacing: TickrLayout.compactItemSpacing) {
                                TickrMetricCard(title: "Upcoming", value: "\(summary.upcomingEvents.count)")
                                TickrMetricCard(title: "High impact", value: "\(summary.highImpactCount)")
                                TickrMetricCard(title: "This week", value: "\(summary.events.count)")
                            }
                        }
                    }

                    TickrCard {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Events Affecting \(summary.symbol)")
                                .font(.headline)
                                .foregroundStyle(TickrPalette.text)

                            if summary.events.isEmpty {
                                Text("No events in the current calendar feed affect this pair.")
                                    .font(.subheadline)
                                    .foregroundStyle(TickrPalette.muted)
                            } else {
                                ForEach(summary.events) { event in
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack(alignment: .top, spacing: 10) {
                                            Circle()
                                                .fill(event.impactLevel.color)
                                                .frame(width: 10, height: 10)
                                                .padding(.top, 4)

                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(event.title)
                                                    .font(.headline)
                                                    .foregroundStyle(TickrPalette.text)

                                                Text("\(CountryDisplay.flag(for: event.countryCode)) \(event.currencyCode) • \(EventPresentation.categoryLabel(for: event.category))")
                                                    .font(.caption)
                                                    .foregroundStyle(TickrPalette.muted)
                                            }

                                            Spacer()

                                            VStack(alignment: .trailing, spacing: 4) {
                                                Text(EventDateFormatter.dayString(from: event.timestamp, useUTC: false))
                                                    .font(.caption.weight(.semibold))
                                                    .foregroundStyle(TickrPalette.muted)

                                                Text(EventDateFormatter.timeString(
                                                    from: event.timestamp,
                                                    useUTC: false,
                                                    use24HourTime: preferences.use24HourTime
                                                ))
                                                .font(.caption.monospacedDigit())
                                                .foregroundStyle(TickrPalette.text)
                                            }
                                        }

                                        if event.actual != nil || event.forecast != nil || event.previous != nil {
                                            HStack(spacing: 8) {
                                                PairEventValuePill(label: "Forecast", value: event.forecast ?? "—")
                                                PairEventValuePill(label: "Previous", value: event.previous ?? "—")
                                                PairEventValuePill(label: "Actual", value: event.actual ?? "—")
                                            }
                                        }

                                        if event.id != summary.events.last?.id {
                                            Divider()
                                                .overlay(TickrPalette.stroke)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        .background(Color.clear)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct PairEventValuePill: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.caption2.weight(.semibold))
                .tracking(1)
                .foregroundStyle(TickrPalette.muted)
            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(TickrPalette.text)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(TickrPalette.surfaceStrong)
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(TickrPalette.stroke, lineWidth: 1)
                }
        )
    }
}

private struct PairDashboardSummary: Identifiable {
    let symbol: String
    let events: [EconomicEvent]

    var id: String { symbol }

    var highImpactCount: Int {
        events.filter { $0.impactLevel == .high }.count
    }

    var upcomingEvents: [EconomicEvent] {
        events.filter { $0.timestamp >= Date() }
    }
}

struct PairCatalogPair: Identifiable, Hashable {
    let symbol: String
    let description: String

    var id: String { symbol }
}

enum PairCatalogCategory: String, CaseIterable, Identifiable {
    case majors
    case crosses
    case exotics

    var id: String { rawValue }

    var title: String {
        switch self {
        case .majors:
            "Majors"
        case .crosses:
            "Crosses"
        case .exotics:
            "Exotics"
        }
    }

    var pairs: [PairCatalogPair] {
        switch self {
        case .majors:
            [
                .init(symbol: "EURUSD", description: "Euro / Dollar"),
                .init(symbol: "GBPUSD", description: "Pound / Dollar"),
                .init(symbol: "USDJPY", description: "Dollar / Yen"),
                .init(symbol: "USDCHF", description: "Dollar / Swissy"),
                .init(symbol: "AUDUSD", description: "Aussie / Dollar"),
                .init(symbol: "USDCAD", description: "Dollar / Loonie"),
                .init(symbol: "NZDUSD", description: "Kiwi / Dollar")
            ]
        case .crosses:
            [
                .init(symbol: "EURGBP", description: "Euro / Pound"),
                .init(symbol: "EURJPY", description: "Euro / Yen"),
                .init(symbol: "GBPJPY", description: "Pound / Yen"),
                .init(symbol: "AUDJPY", description: "Aussie / Yen"),
                .init(symbol: "EURAUD", description: "Euro / Aussie"),
                .init(symbol: "EURCHF", description: "Euro / Swissy"),
                .init(symbol: "CADJPY", description: "Loonie / Yen")
            ]
        case .exotics:
            [
                .init(symbol: "USDSEK", description: "Dollar / Krona"),
                .init(symbol: "USDNOK", description: "Dollar / Krone"),
                .init(symbol: "USDMXN", description: "Dollar / Peso"),
                .init(symbol: "USDZAR", description: "Dollar / Rand"),
                .init(symbol: "USDTRY", description: "Dollar / Lira"),
                .init(symbol: "EURTRY", description: "Euro / Lira")
            ]
        }
    }
}

#Preview {
    NavigationStack {
        PairsPlaceholderView(
            viewModel: CalendarViewModel(service: MockCalendarService()),
            preferences: UserPreferences()
        )
    }
}
