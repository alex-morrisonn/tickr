import SwiftUI

struct PairsPlaceholderView: View {
    var body: some View {
        ContentUnavailableView(
            "Pairs Coming Soon",
            systemImage: "chart.line.uptrend.xyaxis",
            description: Text("Watched pairs and pair-specific event filters will live here.")
        )
        .navigationTitle("Pairs")
    }
}

#Preview {
    NavigationStack {
        PairsPlaceholderView()
    }
}
