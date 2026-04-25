import SwiftUI

/// Animated starfield background — small dots drifting downward at varying
/// speeds with subtle twinkle. Drives itself via TimelineView and renders
/// through SwiftUI Canvas for cheap GPU-accelerated drawing.
///
/// Designed to sit behind any content as a `.background` — pass `density` to
/// dial it up (used on Splash) or down (used on the main scene).
struct StarfieldView: View {
    /// Approximate number of stars on screen at once. The actual count is
    /// computed from the rendered area so density is consistent across iPhones.
    var density: CGFloat = 0.00012   // stars per square point
    /// Min/max fall speed (points/sec).
    var speed: ClosedRange<CGFloat> = 18...60
    /// Whether to draw a subtle drifting aurora behind the stars.
    var aurora: Bool = true

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: false)) { context in
            Canvas { ctx, size in
                let now = context.date.timeIntervalSinceReferenceDate

                if aurora {
                    drawAurora(ctx: ctx, size: size, t: now)
                }

                let area = size.width * size.height
                let count = max(40, Int(area * density))
                drawStars(ctx: ctx, size: size, t: now, count: count)
            }
        }
        .drawingGroup()           // composite once on Metal
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func drawAurora(ctx: GraphicsContext, size: CGSize, t: TimeInterval) {
        // Two slowly-drifting radial blobs blended with .plusLighter for that
        // northern-lights feel. Centres trace gentle Lissajous curves.
        let blobs: [(Color, CGFloat, CGFloat, CGFloat, CGFloat)] = [
            (Color(red: 0.18, green: 0.40, blue: 0.95), 0.31, 0.27, 0.041, 0.058),
            (Color(red: 0.55, green: 0.20, blue: 0.95), 0.69, 0.36, 0.037, 0.063),
            (Color(red: 0.10, green: 0.65, blue: 0.85), 0.50, 0.72, 0.050, 0.043)
        ]
        for (color, baseX, baseY, freqX, freqY) in blobs {
            let cx = baseX * size.width  + sin(t * freqX) * size.width  * 0.18
            let cy = baseY * size.height + cos(t * freqY) * size.height * 0.14
            let radius = max(size.width, size.height) * 0.55
            let rect = CGRect(x: cx - radius, y: cy - radius, width: radius * 2, height: radius * 2)
            var localCtx = ctx
            localCtx.blendMode = .plusLighter
            localCtx.opacity = 0.32
            localCtx.fill(
                Path(ellipseIn: rect),
                with: .radialGradient(
                    Gradient(colors: [color, color.opacity(0.0)]),
                    center: CGPoint(x: cx, y: cy),
                    startRadius: 0,
                    endRadius: radius
                )
            )
        }
    }

    private func drawStars(ctx: GraphicsContext, size: CGSize, t: TimeInterval, count: Int) {
        // Each star is fully determined by its index — no per-frame state.
        // This makes the field deterministic and never "snaps" on resize.
        for i in 0..<count {
            let seed = Double(i) * 12.9898
            let h0 = abs((sin(seed * 78.233) * 43758.5453).truncatingRemainder(dividingBy: 1.0))
            let h1 = abs((sin(seed * 12.345 + 1.0) * 43758.5453).truncatingRemainder(dividingBy: 1.0))
            let h2 = abs((sin(seed * 54.321 + 2.0) * 43758.5453).truncatingRemainder(dividingBy: 1.0))
            let h3 = abs((sin(seed * 37.711 + 3.0) * 43758.5453).truncatingRemainder(dividingBy: 1.0))

            let xBase = h0 * Double(size.width)
            let v = Double(speed.lowerBound) + h1 * Double(speed.upperBound - speed.lowerBound)
            let cycle = Double(size.height) + 60
            let yProgress = (t * v + h2 * cycle).truncatingRemainder(dividingBy: cycle)
            let y = yProgress - 30                                       // start above the top
            let twinkle = 0.55 + 0.45 * sin(t * (1.0 + h3 * 2.0) + Double(i))
            let radius = 0.6 + h3 * 1.6                                  // 0.6 .. 2.2
            let opacity = 0.40 + 0.50 * h2 * twinkle

            let dot = Path(ellipseIn: CGRect(
                x: xBase - radius,
                y: y - radius,
                width: radius * 2,
                height: radius * 2
            ))
            ctx.fill(dot, with: .color(.white.opacity(opacity)))

            // Add a soft glow for the brightest 20% of stars.
            if h3 > 0.8 {
                let glowR = radius * 5
                let glow = Path(ellipseIn: CGRect(
                    x: xBase - glowR,
                    y: y - glowR,
                    width: glowR * 2,
                    height: glowR * 2
                ))
                var localCtx = ctx
                localCtx.blendMode = .plusLighter
                localCtx.opacity = 0.4 * opacity
                localCtx.fill(
                    glow,
                    with: .radialGradient(
                        Gradient(colors: [Color.white.opacity(0.6), Color.white.opacity(0.0)]),
                        center: CGPoint(x: xBase, y: y),
                        startRadius: 0,
                        endRadius: glowR
                    )
                )
            }
        }
    }
}

#Preview {
    ZStack {
        Color.black
        StarfieldView()
    }
    .ignoresSafeArea()
}
