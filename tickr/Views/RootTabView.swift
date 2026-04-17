import SwiftUI

struct RootTabView: View {
    private let calendarService: CalendarService

    init(calendarService: CalendarService = RemoteCalendarService()) {
        self.calendarService = calendarService
    }

    var body: some View {
        TabView {
            NavigationStack {
                CalendarView(service: calendarService)
            }
            .tabItem {
                Label("Calendar", systemImage: "calendar")
            }

            NavigationStack {
                PairsPlaceholderView()
            }
            .tabItem {
                Label("Pairs", systemImage: "chart.line.uptrend.xyaxis")
            }

            NavigationStack {
                SettingsPlaceholderView()
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape")
            }
        }
    }
}

#Preview {
    RootTabView()
}
