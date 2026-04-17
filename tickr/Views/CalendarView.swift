import SwiftUI

@MainActor
struct CalendarView: View {
    @State private var viewModel: CalendarViewModel

    @MainActor
    init(service: CalendarService) {
        _viewModel = State(initialValue: CalendarViewModel(service: service))
    }

    private var groupedEvents: [(day: Date, events: [EconomicEvent])] {
        let grouped = Dictionary(grouping: viewModel.events) { event in
            Calendar.current.startOfDay(for: event.timestamp)
        }

        return grouped
            .map { ($0.key, $0.value.sorted { $0.timestamp < $1.timestamp }) }
            .sorted { $0.day < $1.day }
    }

    var body: some View {
        List {
            if let errorMessage = viewModel.errorMessage {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Unable to Load Events", systemImage: "wifi.slash")
                            .font(.headline)
                        Text(errorMessage)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                }
            }

            ForEach(groupedEvents, id: \.day) { group in
                Section(EventDateFormatter.dayFormatter.string(from: group.day)) {
                    ForEach(group.events) { event in
                        EconomicEventRow(event: event)
                    }
                }
            }
        }
        .overlay {
            if viewModel.isLoading && viewModel.events.isEmpty {
                ProgressView("Loading events...")
            } else if viewModel.events.isEmpty {
                ContentUnavailableView(
                    "No Events Available",
                    systemImage: "calendar.badge.exclamationmark",
                    description: Text(viewModel.errorMessage ?? "Pull to refresh to load the latest calendar.")
                )
            }
        }
        .navigationTitle("Calendar")
        .task {
            guard viewModel.events.isEmpty else { return }
            await viewModel.refresh()
        }
        .refreshable {
            await viewModel.refresh()
        }
    }
}

private struct EconomicEventRow: View {
    let event: EconomicEvent

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: 8)
                .fill(event.impactLevel.color)
                .frame(width: 6)

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text("\(CountryDisplay.flag(for: event.countryCode)) \(event.currencyCode)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text(EventDateFormatter.timeFormatter.string(from: event.timestamp))
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                Text(event.title)
                    .font(.headline)

                HStack(spacing: 10) {
                    EventValueChip(label: "Forecast", value: event.forecast)
                    EventValueChip(label: "Previous", value: event.previous)
                    EventValueChip(label: "Actual", value: event.actual)
                }

                if !event.relatedPairs.isEmpty {
                    Text(event.relatedPairs.joined(separator: " • "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 6)
    }
}

private struct EventValueChip: View {
    let label: String
    let value: String?

    var body: some View {
        Text("\(label): \(value ?? "—")")
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.secondary.opacity(0.08), in: Capsule())
    }
}

#Preview {
    NavigationStack {
        CalendarView(service: MockCalendarService())
    }
}
