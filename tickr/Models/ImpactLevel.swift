import SwiftUI

enum ImpactLevel: String, Codable, CaseIterable, Identifiable {
    case low
    case medium
    case high

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .low:
            .mint
        case .medium:
            .orange
        case .high:
            .red
        }
    }

    var label: String {
        rawValue.capitalized
    }
}
