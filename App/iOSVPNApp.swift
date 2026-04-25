import SwiftUI

@main
struct VPNClientApp: App {
    @StateObject private var appViewModel = AppViewModel()
    @State private var showSplash = true

    var body: some Scene {
        WindowGroup {
            ReachabilityBannerHost {
                ZStack {
                    if !showSplash {
                        RootView()
                            .environmentObject(appViewModel)
                            .environmentObject(appViewModel.serverStore)
                            .environmentObject(appViewModel.vpnManager)
                            .preferredColorScheme(appViewModel.settings.theme.colorScheme)
                            .transition(.opacity.combined(with: .scale(scale: 1.04)))
                    }

                    if showSplash {
                        SplashView()
                            .transition(.opacity)
                            .zIndex(1)
                            .task {
                                await dismissSplashAfterDelay()
                            }
                    }
                }
                .animation(.easeInOut(duration: 0.55), value: showSplash)
            }
        }
    }

    private func dismissSplashAfterDelay() async {
        // Total splash budget: ~3.5s — gives the user time to read the
        // randomly-picked welcome line.
        try? await Task.sleep(nanoseconds: 3_500_000_000)
        await MainActor.run {
            withAnimation(.easeInOut(duration: 0.6)) {
                showSplash = false
            }
        }
    }
}
