import SwiftUI

struct ServerListView: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    @EnvironmentObject private var serverStore: ServerStore

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                StarfieldView(density: 0.00007, speed: 8...30, aurora: true)
                    .opacity(0.65)
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        HStack {
                            Text("Серверы")
                                .font(.system(size: 22, weight: .heavy, design: .rounded))
                                .foregroundStyle(.white)
                            Spacer()
                            Button {
                                Task { await appViewModel.pingAll() }
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "bolt.horizontal.fill")
                                    Text("Пинг всех")
                                }
                                .font(.system(size: 13, weight: .heavy, design: .rounded))
                                .foregroundStyle(.white)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                                .background(Capsule().fill(.ultraThinMaterial))
                                .overlay(Capsule().strokeBorder(Color.white.opacity(0.22), lineWidth: 1))
                            }
                        }
                        .padding(.top, 6)

                        ForEach(serverStore.servers) { server in
                            ServerRow(server: server)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    Task { await appViewModel.selectServer(server) }
                                }
                        }

                        Spacer(minLength: 24)
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 6)
                }
            }
            .preferredColorScheme(.dark)
            .toolbarBackground(.hidden, for: .navigationBar)
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct ServerRow: View {
    let server: Server
    @EnvironmentObject private var appViewModel: AppViewModel

    var body: some View {
        HStack(spacing: 12) {
            Text(server.flagEmoji).font(.system(size: 30))
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(server.name)
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .foregroundStyle(.white)
                    if appViewModel.settings.selectedServerID == server.id {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color(red: 0.45, green: 0.92, blue: 0.66))
                    }
                }
                Text("\(server.address):\(server.port) · \(server.serverName)")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.55))
                if let note = server.note {
                    Text(note)
                        .font(.system(.caption2, design: .rounded, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.55))
                }
            }
            Spacer()
            pingButton
        }
        .padding(14)
        .glassCard(cornerRadius: 16)
    }

    @ViewBuilder
    private var pingButton: some View {
        let result = appViewModel.pings[server.id]
        let pinging = appViewModel.pingingServerIDs.contains(server.id)
        Button {
            Task { await appViewModel.ping(server) }
        } label: {
            HStack(spacing: 4) {
                if pinging {
                    ProgressView().controlSize(.small).tint(.white)
                } else if let ms = result?.latencyMs {
                    Image(systemName: "bolt.fill")
                    Text("\(ms)")
                        .monospacedDigit()
                } else if result != nil {
                    Image(systemName: "xmark.circle.fill")
                } else {
                    Image(systemName: "bolt")
                }
            }
            .font(.system(.footnote, design: .rounded, weight: .heavy))
            .frame(minWidth: 60)
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background(
                Capsule().fill(color(for: result?.latencyMs).opacity(0.2))
            )
            .overlay(
                Capsule().strokeBorder(color(for: result?.latencyMs).opacity(0.45), lineWidth: 1)
            )
            .foregroundStyle(color(for: result?.latencyMs))
        }
        .buttonStyle(.plain)
    }

    private func color(for ms: Int?) -> Color {
        guard let ms else { return Color.white.opacity(0.6) }
        switch ms {
        case 0..<80:    return Color(red: 0.45, green: 0.92, blue: 0.66)
        case 80..<180:  return Color(red: 1.0, green: 0.82, blue: 0.35)
        default:        return Color(red: 1.0, green: 0.42, blue: 0.42)
        }
    }
}
