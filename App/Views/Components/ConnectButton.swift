import SwiftUI

/// Big circular connect button with multi-layer styling:
/// 1. Outer angular-gradient ring (rotates while connecting)
/// 2. Pulsing halo when connected
/// 3. Inner radial-gradient sphere with state-driven palette
/// 4. Glossy highlight on top, soft inner shadow
/// 5. Power glyph that morphs between off / on / busy states
struct ConnectButton: View {
    let state: ConnectionState
    let action: () -> Void

    @State private var ringRotation: Double = 0
    @State private var pulse: CGFloat = 1.0
    @State private var pressed: Bool = false

    private let size: CGFloat = 220

    var body: some View {
        Button(action: action) {
            ZStack {
                // Pulsing halo (only while connected)
                if state == .connected {
                    Circle()
                        .stroke(palette.glow, lineWidth: 22)
                        .frame(width: size, height: size)
                        .scaleEffect(pulse)
                        .opacity(2.0 - Double(pulse))
                        .blur(radius: 6)
                }

                // Outer rotating ring
                Circle()
                    .strokeBorder(
                        AngularGradient(
                            colors: ringColors,
                            center: .center,
                            startAngle: .degrees(0),
                            endAngle: .degrees(360)
                        ),
                        lineWidth: 6
                    )
                    .frame(width: size, height: size)
                    .rotationEffect(.degrees(ringRotation))
                    .opacity(state == .disconnected || state == .failed ? 0.55 : 1.0)

                // Inner sphere
                Circle()
                    .fill(
                        RadialGradient(
                            colors: palette.body,
                            center: .init(x: 0.30, y: 0.30),
                            startRadius: 4,
                            endRadius: size * 0.65
                        )
                    )
                    .frame(width: size - 26, height: size - 26)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.18), lineWidth: 1)
                            .frame(width: size - 26, height: size - 26)
                    )
                    .shadow(color: palette.shadow, radius: 26, x: 0, y: 8)

                // Glossy highlight
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.32), Color.white.opacity(0.0)],
                            startPoint: .top,
                            endPoint: .center
                        )
                    )
                    .frame(width: size - 50, height: size - 50)
                    .offset(y: -8)
                    .blendMode(.plusLighter)
                    .allowsHitTesting(false)

                // Center glyph
                Group {
                    if state == .connecting || state == .reconnecting || state == .disconnecting {
                        ProgressView()
                            .controlSize(.large)
                            .tint(.white)
                    } else {
                        Image(systemName: "power")
                            .font(.system(size: 78, weight: .regular))
                            .foregroundStyle(.white)
                            .shadow(color: Color.black.opacity(0.35), radius: 4, y: 2)
                    }
                }
            }
        }
        .buttonStyle(PressEffectStyle(pressed: $pressed))
        .scaleEffect(pressed ? 0.96 : 1.0)
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: pressed)
        .animation(.spring(response: 0.55, dampingFraction: 0.85), value: state)
        .onAppear { startRotating(); startPulse() }
        .onChange(of: state) { _ in startRotating() }
        .accessibilityLabel(Text(state.localizedTitle))
    }

    // MARK: – Animations

    private func startRotating() {
        // Spin while busy, stand still otherwise.
        let busy = (state == .connecting || state == .reconnecting || state == .disconnecting)
        if busy {
            withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
                ringRotation = 360
            }
        } else {
            // Slow drift to keep it lively.
            withAnimation(.linear(duration: 18).repeatForever(autoreverses: false)) {
                ringRotation = 360
            }
        }
    }

    private func startPulse() {
        withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
            pulse = 1.08
        }
    }

    // MARK: – Palette

    private struct Palette {
        var body: [Color]
        var ring: [Color]
        var glow: Color
        var shadow: Color
    }

    private var palette: Palette {
        switch state {
        case .connected:
            return Palette(
                body:   [Color(red: 0.16, green: 0.85, blue: 0.55),
                         Color(red: 0.05, green: 0.45, blue: 0.32)],
                ring:   [Color(red: 0.24, green: 0.94, blue: 0.66),
                         Color(red: 0.06, green: 0.55, blue: 0.42),
                         Color(red: 0.24, green: 0.94, blue: 0.66)],
                glow:   Color(red: 0.18, green: 0.86, blue: 0.55).opacity(0.55),
                shadow: Color(red: 0.06, green: 0.55, blue: 0.42).opacity(0.55)
            )
        case .connecting, .reconnecting, .disconnecting:
            return Palette(
                body:   [Color(red: 1.00, green: 0.65, blue: 0.20),
                         Color(red: 0.85, green: 0.32, blue: 0.05)],
                ring:   [Color.orange, Color.yellow, Color.orange],
                glow:   Color.orange.opacity(0.55),
                shadow: Color.orange.opacity(0.55)
            )
        case .failed:
            return Palette(
                body:   [Color(red: 0.95, green: 0.32, blue: 0.30),
                         Color(red: 0.55, green: 0.12, blue: 0.12)],
                ring:   [Color.red, Color(red: 0.85, green: 0.20, blue: 0.20), Color.red],
                glow:   Color.red.opacity(0.55),
                shadow: Color.red.opacity(0.55)
            )
        case .disconnected:
            return Palette(
                body:   [Color(red: 0.30, green: 0.55, blue: 1.00),
                         Color(red: 0.10, green: 0.22, blue: 0.55)],
                ring:   [Color(red: 0.40, green: 0.66, blue: 1.00),
                         Color(red: 0.20, green: 0.40, blue: 0.85),
                         Color(red: 0.40, green: 0.66, blue: 1.00)],
                glow:   Color.accentColor.opacity(0.45),
                shadow: Color.accentColor.opacity(0.45)
            )
        }
    }

    private var ringColors: [Color] { palette.ring }
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
