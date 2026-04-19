import SwiftUI

enum ImpactLevel: String, Codable, CaseIterable, Identifiable {
    case low
    case medium
    case high

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .low:
            .gray
        case .medium:
            .orange
        case .high:
            .red
        }
    }

    var label: String {
        rawValue.capitalized
    }

    var rank: Int {
        switch self {
        case .low:
            0
        case .medium:
            1
        case .high:
            2
        }
    }
}
