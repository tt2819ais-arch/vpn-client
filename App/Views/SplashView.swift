import SwiftUI

/// Pre-launch splash with smooth fade-in / fade-out.
/// Shows "VPN CLIENT" plus a Telegram-styled "@MaksimXyila" credit line.
struct SplashView: View {
    @State private var titleOpacity: Double = 0
    @State private var titleOffset: CGFloat = 18
    @State private var creditOpacity: Double = 0
    @State private var creditOffset: CGFloat = 12
    @State private var glowScale: CGFloat = 0.9

    var body: some View {
        ZStack {
            // Soft animated background gradient
            LinearGradient(
                colors: [
                    Color(red: 0.06, green: 0.08, blue: 0.12),
                    Color(red: 0.10, green: 0.13, blue: 0.20)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // Subtle radial glow
            RadialGradient(
                colors: [
                    Color.accentColor.opacity(0.35),
                    Color.clear
                ],
                center: .center,
                startRadius: 8,
                endRadius: 280
            )
            .scaleEffect(glowScale)
            .blur(radius: 28)
            .opacity(0.7)
            .ignoresSafeArea()

            VStack(spacing: 14) {
                Spacer()

                Image(systemName: "shield.lefthalf.filled.badge.checkmark")
                    .font(.system(size: 64, weight: .semibold))
                    .foregroundStyle(Color.white, Color.accentColor)
                    .opacity(titleOpacity)
                    .offset(y: titleOffset * -1)
                    .padding(.bottom, 8)

                Text("VPN CLIENT")
                    .font(.system(size: 38, weight: .heavy, design: .rounded))
                    .tracking(6)
                    .foregroundStyle(.white)
                    .opacity(titleOpacity)
                    .offset(y: titleOffset)

                Spacer()

                HStack(spacing: 8) {
                    TelegramGlyph()
                        .frame(width: 22, height: 22)
                    Text("@MaksimXyila")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.9))
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(
                    Capsule(style: .continuous)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            Capsule(style: .continuous)
                                .stroke(.white.opacity(0.12), lineWidth: 1)
                        )
                )
                .opacity(creditOpacity)
                .offset(y: creditOffset)
                .padding(.bottom, 36)
            }
            .padding()
        }
        .onAppear(perform: animateIn)
    }

    private func animateIn() {
        withAnimation(.spring(response: 0.7, dampingFraction: 0.85)) {
            titleOpacity = 1
            titleOffset = 0
            glowScale = 1.15
        }
        withAnimation(.easeOut(duration: 0.7).delay(0.5)) {
            creditOpacity = 1
            creditOffset = 0
        }
    }
}

/// Hand-drawn Telegram paper-plane glyph so we don't rely on bundled assets.
struct TelegramGlyph: View {
    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height)
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 0.15, green: 0.65, blue: 0.95),
                                     Color(red: 0.10, green: 0.45, blue: 0.85)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                Image(systemName: "paperplane.fill")
                    .font(.system(size: s * 0.55, weight: .bold))
                    .foregroundStyle(.white)
                    .offset(x: -s * 0.04, y: s * 0.02)
                    .rotationEffect(.degrees(-6))
            }
        }
    }
}

#Preview {
    SplashView()
}
