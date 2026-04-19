import SwiftUI

struct SplashScreenView: View {
    var body: some View {
        ZStack {
            TickrBackground()

            VStack(spacing: 18) {
                VStack(spacing: 10) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(TickrPalette.accent)

                    Text("Tickr")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(TickrPalette.text)

                    Text("Your market week, at a glance.")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(TickrPalette.muted)
                }

                HStack(spacing: 8) {
                    SplashPulseBar(width: 38)
                    SplashPulseBar(width: 18)
                    SplashPulseBar(width: 26)
                }
            }
            .padding(.horizontal, 24)
        }
    }
}

private struct SplashPulseBar: View {
    let width: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: 3, style: .continuous)
            .fill(TickrPalette.surfaceStrong)
            .frame(width: width, height: 6)
            .overlay {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .stroke(TickrPalette.stroke, lineWidth: 1)
            }
    }
}

#Preview {
    SplashScreenView()
        .preferredColorScheme(.dark)
}
