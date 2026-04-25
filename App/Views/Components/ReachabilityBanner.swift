import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Branded banner that appears in the extra top space iOS exposes when the
/// user activates Reachability (swipe-down on the home indicator).
///
/// Implementation: a full-window UIViewControllerRepresentable installed as a
/// `.background` of the content. Because that representable spans the whole
/// window (it ignores safe areas itself), `viewSafeAreaInsetsDidChange` always
/// fires with the *true* window safe-area inset. We compare against the device
/// baseline captured on first appearance and show the banner whenever the
/// inset jumps significantly (Reachability adds ≈ half-screen of empty space
/// at the top — ~250pt+ — but we only need a much smaller delta to trigger).
struct ReachabilityBannerHost<Content: View>: View {
    @ViewBuilder var content: Content

    @State private var topInset: CGFloat = 0
    @State private var baselineTopInset: CGFloat = -1
    @State private var isVisible: Bool = false

    /// Reachability adds well over 200pt of inset — anything above ~24pt over
    /// the baseline is unambiguously Reachability (StatusBar phone-call banner
    /// is only ~20pt and we ignore it intentionally).
    private let activationDelta: CGFloat = 24

    var body: some View {
        ZStack(alignment: .top) {
            content
                .background(
                    SafeAreaInsetsReader(topInset: $topInset)
                        .ignoresSafeArea(.all)
                        .allowsHitTesting(false)
                )

            if isVisible {
                ReachabilityBanner(extraHeight: max(0, topInset - max(baselineTopInset, 0)))
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .ignoresSafeArea(.all, edges: .top)
                    .zIndex(2)
            }
        }
        .onChange(of: topInset) { newValue in
            if baselineTopInset < 0 {
                baselineTopInset = newValue
                LogStore.shared.debug("Reachability baseline = \(Int(newValue))pt", tag: "Reachability")
                return
            }
            // Track the smallest observed inset as the baseline (handles
            // rotation, multitasking, status bar changes).
            if newValue < baselineTopInset {
                baselineTopInset = newValue
            }
            let active = (newValue - baselineTopInset) > activationDelta
            if active != isVisible {
                LogStore.shared.info("Reachability \(active ? "ON" : "OFF") (top inset \(Int(newValue))pt, baseline \(Int(baselineTopInset))pt)", tag: "Reachability")
            }
            withAnimation(.spring(response: 0.42, dampingFraction: 0.85)) {
                isVisible = active
            }
        }
    }
}

private struct ReachabilityBanner: View {
    let extraHeight: CGFloat

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.13, green: 0.42, blue: 0.92),
                    Color(red: 0.18, green: 0.55, blue: 0.99)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            HStack(spacing: 8) {
                TelegramGlyph().frame(width: 22, height: 22)
                Text("@MaksimXyila")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.white)
                    .shadow(color: Color.black.opacity(0.25), radius: 1, y: 1)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: max(extraHeight, 64))
    }
}

#if canImport(UIKit)
private struct SafeAreaInsetsReader: UIViewControllerRepresentable {
    @Binding var topInset: CGFloat

    func makeUIViewController(context: Context) -> InsetReadingController {
        let vc = InsetReadingController()
        vc.onChange = { value in
            DispatchQueue.main.async {
                if abs(self.topInset - value) > 0.5 {
                    self.topInset = value
                }
            }
        }
        return vc
    }

    func updateUIViewController(_ uiViewController: InsetReadingController, context: Context) {}
}

private final class InsetReadingController: UIViewController {
    var onChange: ((CGFloat) -> Void)?

    override func loadView() {
        let v = UIView()
        v.backgroundColor = .clear
        v.isUserInteractionEnabled = false
        view = v
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        edgesForExtendedLayout = .all
        extendedLayoutIncludesOpaqueBars = true
        // Also publish current value on first appearance.
        onChange?(view.safeAreaInsets.top)
    }

    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        onChange?(view.safeAreaInsets.top)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        onChange?(view.safeAreaInsets.top)
    }
}
#else
private struct SafeAreaInsetsReader: View {
    @Binding var topInset: CGFloat
    var body: some View { Color.clear }
}
#endif
