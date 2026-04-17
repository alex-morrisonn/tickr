import SwiftUI

struct SettingsPlaceholderView: View {
    var body: some View {
        ContentUnavailableView(
            "Settings Coming Soon",
            systemImage: "gearshape",
            description: Text("Timezone, alerts, and preferences will be configured here.")
        )
        .navigationTitle("Settings")
    }
}

#Preview {
    NavigationStack {
        SettingsPlaceholderView()
    }
}
