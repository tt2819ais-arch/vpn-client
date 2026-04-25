import SwiftUI

/// Splash screen shown for ~2.4s before the app reveals itself.
///
/// Visual: pure-black backdrop, full-screen `StarfieldView` (drifting stars +
/// aurora), and three layers of typography that fade/translate in:
///
///   1. Bold rounded `VPN CLIENT` headline
///   2. A randomly-picked welcome message from `WelcomeMessages.all`
///   3. `@MaksimXyila` Telegram credit chip
///
/// All text is bold rounded — matches the new global type system.
struct SplashView: View {
    @State private var titleOpacity: Double = 0
    @State private var titleOffset: CGFloat = 24
    @State private var messageOpacity: Double = 0
    @State private var messageOffset: CGFloat = 16
    @State private var creditOpacity: Double = 0
    @State private var creditOffset: CGFloat = 12
    @State private var welcome: String = WelcomeMessages.random()

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            StarfieldView(density: 0.00018, speed: 22...80, aurora: true)
                .ignoresSafeArea()

            VStack(spacing: 18) {
                Spacer()

                Image(systemName: "shield.lefthalf.filled.badge.checkmark")
                    .font(.system(size: 64, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.white, Color(white: 0.65)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: Color.white.opacity(0.20), radius: 18, y: 0)
                    .opacity(titleOpacity)
                    .offset(y: -titleOffset)

                Text("VPN CLIENT")
                    .font(.system(size: 40, weight: .heavy, design: .rounded))
                    .tracking(7)
                    .foregroundStyle(.white)
                    .shadow(color: Color.black.opacity(0.5), radius: 6)
                    .opacity(titleOpacity)
                    .offset(y: titleOffset)

                Spacer().frame(maxHeight: 28)

                Text(welcome)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.white.opacity(0.92))
                    .shadow(color: Color.black.opacity(0.5), radius: 4)
                    .padding(.horizontal, 28)
                    .opacity(messageOpacity)
                    .offset(y: messageOffset)

                Spacer()

                HStack(spacing: 8) {
                    TelegramGlyph().frame(width: 22, height: 22)
                    Text("@MaksimXyila")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(
                    Capsule(style: .continuous)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            Capsule(style: .continuous)
                                .stroke(Color.white.opacity(0.18), lineWidth: 1)
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
        LogStore.shared.info("Splash: '\(welcome)'", tag: "UI")
        withAnimation(.spring(response: 0.7, dampingFraction: 0.85)) {
            titleOpacity = 1
            titleOffset = 0
        }
        withAnimation(.easeOut(duration: 0.7).delay(0.35)) {
            messageOpacity = 1
            messageOffset = 0
        }
        withAnimation(.easeOut(duration: 0.7).delay(0.7)) {
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
                            colors: [Color(white: 0.20),
                                     Color(white: 0.05)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(
                        Circle().stroke(Color.white.opacity(0.20), lineWidth: 1)
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
