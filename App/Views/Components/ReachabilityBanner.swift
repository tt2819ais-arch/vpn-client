import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Branded banner that appears in the extra top space iOS exposes when the
/// user activates Reachability (swipe-down on the home indicator). Hidden by
/// default; the host installs a `SafeAreaInsetsReader` that updates a binding
/// with the current top safe-area inset, and we toggle visibility based on
/// whether that inset is meaningfully larger than the device baseline.
struct ReachabilityBannerHost<Content: View>: View {
    @ViewBuilder var content: Content

    @State private var topInset: CGFloat = 0
    @State private var baselineTopInset: CGFloat = 0
    @State private var isVisible: Bool = false

    private let activationDelta: CGFloat = 40

    var body: some View {
        ZStack(alignment: .top) {
            content

            // Invisible reader behind the content
            SafeAreaInsetsReader(topInset: $topInset)
                .frame(width: 0, height: 0)
                .accessibilityHidden(true)

            if isVisible {
                ReachabilityBanner(extraHeight: max(0, topInset - baselineTopInset))
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .ignoresSafeArea(.all, edges: .top)
            }
        }
        .onChange(of: topInset) { newValue in
            if baselineTopInset == 0 {
                baselineTopInset = newValue
                return
            }
            // If we observe a smaller value later, treat it as the new baseline
            // (rotation, multitasking, etc.).
            if newValue < baselineTopInset {
                baselineTopInset = newValue
            }
            let active = newValue - baselineTopInset > activationDelta
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
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.25), radius: 1, y: 1)
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
            DispatchQueue.main.async { self.topInset = value }
        }
        return vc
    }

    func updateUIViewController(_ uiViewController: InsetReadingController, context: Context) {}
}

private final class InsetReadingController: UIViewController {
    var onChange: ((CGFloat) -> Void)?

    override func loadView() {
        view = UIView()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
    }

    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        onChange?(view.safeAreaInsets.top)
    }
}
#else
private struct SafeAreaInsetsReader: View {
    @Binding var topInset: CGFloat
    var body: some View { Color.clear }
}
#endif
