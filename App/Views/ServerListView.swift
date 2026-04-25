import SwiftUI

struct ServerListView: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    @EnvironmentObject private var serverStore: ServerStore

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(serverStore.servers) { server in
                        ServerRow(server: server)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                Task { await appViewModel.selectServer(server) }
                            }
                    }
                } header: {
                    HStack {
                        Text("Серверы")
                        Spacer()
                        Button {
                            Task { await appViewModel.pingAll() }
                        } label: {
                            Label("Пинг всех", systemImage: "bolt.horizontal.fill")
                                .labelStyle(.titleAndIcon)
                                .font(.caption.weight(.semibold))
                        }
                    }
                }
            }
            .navigationTitle("Серверы")
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
                        .font(.headline)
                    if appViewModel.settings.selectedServerID == server.id {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color.accentColor)
                    }
                }
                Text("\(server.address):\(server.port) · \(server.serverName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospaced()
                if let note = server.note {
                    Text(note)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer()
            pingButton
        }
        .padding(.vertical, 4)
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
                    ProgressView().controlSize(.small)
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
            .font(.system(.footnote, design: .rounded, weight: .semibold))
            .frame(minWidth: 60)
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background(
                Capsule().fill(color(for: result?.latencyMs).opacity(0.15))
            )
            .foregroundStyle(color(for: result?.latencyMs))
        }
        .buttonStyle(.plain)
    }

    private func color(for ms: Int?) -> Color {
        guard let ms else { return .secondary }
        switch ms {
        case 0..<80:    return .green
        case 80..<180:  return .yellow
        default:        return .red
        }
    }
}
