import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Branded banner that appears in the empty space iOS exposes when the user
/// activates Reachability (swipe-down on the home indicator).
///
/// On iPhones with a notch / Dynamic Island (X and later), Reachability is
/// implemented by translating the key `UIWindow` downwards via `transform.ty`,
/// **not** by changing `safeAreaInsets`. So we drive a `CADisplayLink`-backed
/// observer that polls the window's transform and bounds every frame and
/// publishes the offset. When the offset crosses ~50pt we render the banner
/// in the freshly-revealed top space.
///
/// This component is intentionally chatty in the log — it emits the current
/// transform / bounds values whenever they change so we can debug in the
/// field on devices we don't have.
struct ReachabilityBannerHost<Content: View>: View {
    @ViewBuilder var content: Content

    @StateObject private var observer = ReachabilityObserver()

    var body: some View {
        ZStack(alignment: .top) {
            content

            if observer.isActive {
                ReachabilityBanner(height: max(observer.offset, 64))
                    .frame(height: max(observer.offset, 64))
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .ignoresSafeArea(.all, edges: .top)
                    .zIndex(2)
            }
        }
        .animation(.spring(response: 0.42, dampingFraction: 0.85), value: observer.isActive)
        .onAppear { observer.start() }
        .onDisappear { observer.stop() }
    }
}

private struct ReachabilityBanner: View {
    let height: CGFloat

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(white: 0.10),
                    Color(white: 0.02)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .overlay(
                Rectangle().fill(Color.white.opacity(0.04))
            )

            HStack(spacing: 8) {
                TelegramGlyph().frame(width: 22, height: 22)
                Text("@MaksimXyila")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.white)
                    .shadow(color: Color.black.opacity(0.25), radius: 1, y: 1)
            }
            .padding(.bottom, 8)
        }
        .frame(maxWidth: .infinity)
        .frame(height: height, alignment: .bottom)
    }
}

#if canImport(UIKit)
@MainActor
private final class ReachabilityObserver: ObservableObject {
    @Published var isActive: Bool = false
    @Published var offset: CGFloat = 0

    private var displayLink: CADisplayLink?
    private var lastReportedTy: CGFloat = -1
    private var lastReportedBoundsY: CGFloat = -1
    private var lastReportedFrameY: CGFloat = -1
    private let activationThreshold: CGFloat = 50

    func start() {
        guard displayLink == nil else { return }
        let link = CADisplayLink(target: self, selector: #selector(tick))
        link.preferredFramesPerSecond = 6   // 6 Hz is plenty — Reachability is a slow user gesture
        link.add(to: .main, forMode: .common)
        displayLink = link
        LogStore.shared.debug("ReachabilityObserver started", tag: "Reachability")
    }

    func stop() {
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc private func tick() {
        guard let window = Self.keyWindow else { return }

        let ty = window.transform.ty
        let boundsY = window.bounds.origin.y
        let frameY = window.frame.origin.y

        // Log whenever any of the three meaningful values shift — helps debug
        // which mechanism iOS is actually using on a given device.
        let tyChanged = abs(ty - lastReportedTy) > 1
        let boundsChanged = abs(boundsY - lastReportedBoundsY) > 1
        let frameChanged = abs(frameY - lastReportedFrameY) > 1

        if tyChanged || boundsChanged || frameChanged {
            LogStore.shared.debug(
                "Window probe: transform.ty=\(Int(ty)) bounds.y=\(Int(boundsY)) frame.y=\(Int(frameY))",
                tag: "Reachability"
            )
            lastReportedTy = ty
            lastReportedBoundsY = boundsY
            lastReportedFrameY = frameY
        }

        // Reachability shifts content down. On notch iPhones (X+ incl. 11),
        // it sets `window.transform.ty` to a positive value (~half-screen).
        // On older phones it adjusts `frame.origin.y`. Take whichever is
        // largest and treat as the offset.
        let candidateOffset = max(ty, frameY, -boundsY, 0)
        let active = candidateOffset > activationThreshold

        if active != isActive {
            LogStore.shared.info(
                "Reachability \(active ? "ON" : "OFF") (offset \(Int(candidateOffset))pt)",
                tag: "Reachability"
            )
            isActive = active
        }
        if active {
            offset = candidateOffset
        } else if offset != 0 {
            offset = 0
        }
    }

    private static var keyWindow: UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow } ??
        UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.windows.first }
            .first
    }
}
#else
@MainActor
private final class ReachabilityObserver: ObservableObject {
    @Published var isActive: Bool = false
    @Published var offset: CGFloat = 0
    func start() {}
    func stop() {}
}
#endif
