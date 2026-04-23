import SwiftUI

enum TickrPalette {
    static let backgroundTop = adaptive(
        light: Color(red: 0.95, green: 0.96, blue: 0.94),
        dark: Color.black
    )
    static let backgroundBottom = adaptive(
        light: Color(red: 0.90, green: 0.92, blue: 0.90),
        dark: Color.black
    )
    static let surface = adaptive(
        light: Color.white,
        dark: Color(red: 0.05, green: 0.06, blue: 0.08)
    )
    static let surfaceStrong = adaptive(
        light: Color(red: 0.96, green: 0.97, blue: 0.98),
        dark: Color(red: 0.08, green: 0.10, blue: 0.12)
    )
    static let stroke = adaptive(
        light: Color.black.opacity(0.08),
        dark: Color.white.opacity(0.10)
    )
    static let text = adaptive(
        light: Color(red: 0.11, green: 0.14, blue: 0.12),
        dark: Color(red: 0.88, green: 0.91, blue: 0.94)
    )
    static let muted = adaptive(
        light: Color(red: 0.36, green: 0.40, blue: 0.37),
        dark: Color(red: 0.55, green: 0.58, blue: 0.63)
    )
    static let accent = adaptive(
        light: Color(red: 0.07, green: 0.42, blue: 0.56),
        dark: Color(red: 0.10, green: 0.63, blue: 0.74)
    )
    static let accentSoft = adaptive(
        light: Color(red: 0.83, green: 0.92, blue: 0.96),
        dark: Color(red: 0.08, green: 0.17, blue: 0.22)
    )
    static let success = adaptive(
        light: Color(red: 0.11, green: 0.55, blue: 0.33),
        dark: Color(red: 0.24, green: 0.74, blue: 0.46)
    )
    static let warning = adaptive(
        light: .orange,
        dark: .orange
    )
    static let danger = adaptive(
        light: .red,
        dark: .red
    )

    private static func adaptive(light: Color, dark: Color) -> Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
    }
}

enum TickrLayout {
    static let horizontalPadding: CGFloat = 16
    static let topPadding: CGFloat = 12
    static let bottomPadding: CGFloat = 108
    static let maxContentWidth: CGFloat = 760
    static let compactItemSpacing: CGFloat = 8
    static let sectionSpacing: CGFloat = 14
}

struct TickrBackground: View {
    var body: some View {
        TickrPalette.backgroundTop
        .ignoresSafeArea()
    }
}

struct TickrScreen<Content: View>: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        let isRegularWidth = horizontalSizeClass == .regular

        content
            .frame(maxWidth: isRegularWidth ? 820 : TickrLayout.maxContentWidth, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal, isRegularWidth ? 24 : TickrLayout.horizontalPadding)
            .padding(.top, isRegularWidth ? 16 : TickrLayout.topPadding)
            .padding(.bottom, isRegularWidth ? 120 : TickrLayout.bottomPadding)
    }
}

struct TickrCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(TickrPalette.surface)
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(TickrPalette.stroke, lineWidth: 1)
                    }
            )
    }
}

struct TickrSectionHeader: View {
    let eyebrow: String
    let title: String
    let subtitle: String?

    init(eyebrow: String, title: String, subtitle: String? = nil) {
        self.eyebrow = eyebrow
        self.title = title
        self.subtitle = subtitle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(eyebrow.uppercased())
                .font(.caption.weight(.semibold))
                .tracking(1.2)
                .foregroundStyle(TickrPalette.muted)

            Text(title)
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(TickrPalette.text)

            if let subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(TickrPalette.muted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct TickrPill: View {
    let text: String
    var tint: Color = TickrPalette.surfaceStrong

    var body: some View {
            Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(TickrPalette.text)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(tint)
                    .overlay {
                        Capsule(style: .continuous)
                            .stroke(TickrPalette.stroke, lineWidth: 1)
                    }
            )
    }
}

struct TickrMetricCard: View {
    let title: String
    let value: String
    var tint: Color = TickrPalette.surfaceStrong

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.caption2.weight(.semibold))
                .tracking(1)
                .foregroundStyle(TickrPalette.muted)

            Text(value)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(TickrPalette.text)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .padding(12)
        .frame(minHeight: 68, alignment: .topLeading)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(tint)
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(TickrPalette.stroke, lineWidth: 1)
                }
        )
    }
}

struct TickrInfoRow: View {
    let label: String
    let value: String

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 16) {
                Text(label)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(TickrPalette.muted)

                Spacer(minLength: 24)

                Text(value)
                    .font(.subheadline)
                    .foregroundStyle(TickrPalette.text)
                    .multilineTextAlignment(.trailing)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(label)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(TickrPalette.muted)

                Text(value)
                    .font(.subheadline)
                    .foregroundStyle(TickrPalette.text)
                    .multilineTextAlignment(.leading)
            }
        }
    }
}
