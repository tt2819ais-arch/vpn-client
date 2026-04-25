import SwiftUI

/// Drop-in `.background` for cards that should look like Apple's
/// "Liquid Glass" — translucent, blurred, with a thin white rim highlight.
struct GlassCardBackground: ViewModifier {
    var cornerRadius: CGFloat = 18
    var strokeOpacity: Double = 0.18

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(strokeOpacity * 1.6),
                                Color.white.opacity(strokeOpacity * 0.4),
                                Color.white.opacity(0)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: Color.black.opacity(0.25), radius: 14, y: 6)
    }
}

extension View {
    /// Wraps the view in the Liquid Glass card chrome.
    func glassCard(cornerRadius: CGFloat = 18) -> some View {
        modifier(GlassCardBackground(cornerRadius: cornerRadius))
    }
}

/// Unified primary button style — dark glass capsule with white bold text.
struct GlassPrimaryButtonStyle: ButtonStyle {
    var fillOpacity: Double = 0.18

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.vertical, 12)
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity)
            .background(
                Capsule(style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(Color.white.opacity(0.22), lineWidth: 1)
            )
            .overlay(
                Capsule(style: .continuous)
                    .fill(Color.white.opacity(configuration.isPressed ? fillOpacity * 1.6 : fillOpacity))
                    .blendMode(.plusLighter)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.78), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == GlassPrimaryButtonStyle {
    static var glassPrimary: GlassPrimaryButtonStyle { GlassPrimaryButtonStyle() }
}
