import SwiftUI

struct RootView: View {
    @EnvironmentObject private var appViewModel: AppViewModel

    var body: some View {
        TabView(selection: $appViewModel.selectedTab) {
            ConnectionView()
                .tabItem {
                    Label("Главная", systemImage: "shield.lefthalf.filled")
                }
                .tag(AppTab.connection)

            ServerListView()
                .tabItem {
                    Label("Серверы", systemImage: "server.rack")
                }
                .tag(AppTab.servers)

            SettingsView()
                .tabItem {
                    Label("Настройки", systemImage: "gearshape")
                }
                .tag(AppTab.settings)
        }
        .tint(.white)
        .preferredColorScheme(.dark)
    }
}

enum AppTab: Hashable {
    case connection, servers, settings
}
