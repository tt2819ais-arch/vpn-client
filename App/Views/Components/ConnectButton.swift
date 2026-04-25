import SwiftUI

/// Connect button in Apple "Liquid Glass" / visionOS style:
/// - `.ultraThinMaterial` body (true blur — picks up colour from the scene
///   behind it, sits naturally on any background)
/// - Subtle white→clear inner border for the rim highlight
/// - Soft outer halo that only appears while connected (very low opacity)
/// - Single SF Symbol glyph in the centre, no decorative gradient sphere
/// - Minimal motion: a slow rotation of an arc when busy, a gentle breathing
///   scale when connected, otherwise completely still
struct ConnectButton: View {
    let state: ConnectionState
    let action: () -> Void

    @State private var spin: Double = 0
    @State private var breathe: CGFloat = 1.0
    @State private var pressed: Bool = false

    private let size: CGFloat = 196

    var body: some View {
        Button(action: action) {
            ZStack {
                // 1. Ambient halo — barely-there glow only while connected.
                if state == .connected {
                    Circle()
                        .fill(accent.opacity(0.18))
                        .frame(width: size + 28, height: size + 28)
                        .blur(radius: 22)
                        .scaleEffect(breathe)
                        .allowsHitTesting(false)
                }

                // 2. Glass body.
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: size, height: size)
                    .overlay {
                        // 2a. Rim highlight — bright top, fading to nothing.
                        Circle()
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.55),
                                        Color.white.opacity(0.08),
                                        Color.white.opacity(0.0),
                                        Color.white.opacity(0.18)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 1
                            )
                    }
                    .overlay {
                        // 2b. Inner depth — accent tint while connected, neutral otherwise.
                        Circle()
                            .stroke(accent.opacity(state == .connected ? 0.45 : 0.0), lineWidth: 1.2)
                            .blur(radius: 0.5)
                            .frame(width: size - 6, height: size - 6)
                    }
                    .overlay {
                        // 2c. Top gloss highlight — single linear streak, very subtle.
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.18),
                                        Color.white.opacity(0.0)
                                    ],
                                    startPoint: .top,
                                    endPoint: .center
                                )
                            )
                            .frame(width: size - 16, height: size - 16)
                            .blendMode(.plusLighter)
                            .allowsHitTesting(false)
                    }
                    .shadow(color: Color.black.opacity(0.35), radius: 22, y: 10)

                // 3. Spinning arc while busy — very thin, subtle.
                if isBusy {
                    Circle()
                        .trim(from: 0.0, to: 0.18)
                        .stroke(
                            accent.opacity(0.85),
                            style: StrokeStyle(lineWidth: 2.2, lineCap: .round)
                        )
                        .frame(width: size + 10, height: size + 10)
                        .rotationEffect(.degrees(spin))
                        .allowsHitTesting(false)
                }

                // 4. Centre glyph.
                centerGlyph
            }
        }
        .buttonStyle(PressEffectStyle(pressed: $pressed))
        .scaleEffect(pressed ? 0.97 : 1.0)
        .animation(.spring(response: 0.35, dampingFraction: 0.78), value: pressed)
        .animation(.spring(response: 0.6, dampingFraction: 0.85), value: state)
        .onAppear { startSpin(); startBreathing() }
        .onChange(of: state) { _ in startSpin() }
        .accessibilityLabel(Text(state.localizedTitle))
    }

    // MARK: – Centre glyph

    @ViewBuilder
    private var centerGlyph: some View {
        if isBusy {
            ProgressView()
                .controlSize(.regular)
                .tint(.white)
        } else {
            Image(systemName: state == .connected ? "power" : "power")
                .font(.system(size: 64, weight: .light, design: .rounded))
                .foregroundStyle(
                    state == .connected
                        ? AnyShapeStyle(accent)
                        : AnyShapeStyle(Color.white.opacity(0.92))
                )
                .shadow(color: Color.black.opacity(0.25), radius: 4, y: 2)
        }
    }

    private var isBusy: Bool {
        state == .connecting || state == .reconnecting || state == .disconnecting
    }

    // MARK: – Accent

    private var accent: Color {
        switch state {
        case .connected:    return Color(red: 0.40, green: 0.85, blue: 0.65) // mint
        case .failed:       return Color(red: 0.95, green: 0.42, blue: 0.42)
        default:            return Color.white                              // mono — disconnected/idle
        }
    }

    // MARK: – Animations

    private func startSpin() {
        if isBusy {
            withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                spin = 360
            }
        } else {
            // Stop spinning — leave at current angle, no animation.
            withAnimation(.easeOut(duration: 0.2)) {
                spin = 0
            }
        }
    }

    private func startBreathing() {
        withAnimation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true)) {
            breathe = 1.06
        }
    }
}

private struct PressEffectStyle: ButtonStyle {
    @Binding var pressed: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .onChange(of: configuration.isPressed) { newValue in
                pressed = newValue
            }
    }
}
