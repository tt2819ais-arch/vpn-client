import SwiftUI

struct ConnectionView: View {
    @EnvironmentObject private var appViewModel: AppViewModel

    var body: some View {
        NavigationStack {
            // TimelineView ticks every second on its own — far more reliable
            // than Timer.publish + onReceive, especially across tab changes.
            TimelineView(.periodic(from: Date(), by: 1)) { context in
                ScrollView {
                    VStack(spacing: 22) {
                        statusHeader(now: context.date)
                        bigToggle
                        if let server = appViewModel.selectedServer {
                            currentServerCard(server)
                        }
                        statsGrid
                        Spacer(minLength: 12)
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 6)
                }
                .background(Color(.systemBackground))
            }
            .navigationTitle("VPN Client")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Ошибка", isPresented: errorPresented) {
                Button("OK", role: .cancel) { appViewModel.lastError = nil }
            } message: {
                Text(appViewModel.lastError ?? "")
            }
        }
    }

    private var errorPresented: Binding<Bool> {
        Binding(
            get: { appViewModel.lastError != nil },
            set: { if !$0 { appViewModel.lastError = nil } }
        )
    }

    // MARK: – Subviews

    private func statusHeader(now: Date) -> some View {
        VStack(spacing: 6) {
            Text(appViewModel.connection.state.localizedTitle)
                .font(.system(.title3, design: .rounded, weight: .semibold))
                .foregroundStyle(.secondary)

            if let since = appViewModel.connection.connectedSince,
               appViewModel.connection.state == .connected {
                Text(ByteFormat.duration(now.timeIntervalSince(since)))
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                    .contentTransition(.numericText())
            } else {
                Text("00:00")
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 6)
    }

    private var bigToggle: some View {
        ConnectButton(
            state: appViewModel.connection.state,
            action: { Task { await appViewModel.toggleConnection() } }
        )
    }

    private func currentServerCard(_ server: Server) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Text(server.flagEmoji)
                    .font(.system(size: 34))
                VStack(alignment: .leading, spacing: 2) {
                    Text(server.name)
                        .font(.system(.headline, design: .rounded))
                    Text("\(server.address) · :\(server.port)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospaced()
                }
                Spacer()
                pingBadge(for: server)
            }
            .padding(14)
            if let country = appViewModel.country {
                Divider().padding(.leading, 14)
                HStack(spacing: 8) {
                    Image(systemName: "globe")
                        .foregroundStyle(.secondary)
                    Text(country)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                    Spacer()
                    Button {
                        Task { await appViewModel.refreshCountry() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.subheadline)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }

    @ViewBuilder
    private func pingBadge(for server: Server) -> some View {
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
                    Text("\(ms) мс")
                        .monospacedDigit()
                } else if result != nil {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text("—")
                } else {
                    Image(systemName: "bolt")
                    Text("Пинг")
                }
            }
            .font(.system(.footnote, design: .rounded, weight: .semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule().fill(pingColor(for: result?.latencyMs).opacity(0.15))
            )
            .foregroundStyle(pingColor(for: result?.latencyMs))
        }
        .buttonStyle(.plain)
    }

    private func pingColor(for ms: Int?) -> Color {
        guard let ms else { return .secondary }
        switch ms {
        case 0..<80:    return .green
        case 80..<180:  return .yellow
        default:        return .red
        }
    }

    private var statsGrid: some View {
        let stats = appViewModel.connection.stats
        return HStack(spacing: 12) {
            statTile(
                title: "Скачано",
                value: ByteFormat.string(stats.rxBytes),
                rate: ByteFormat.rate(stats.rxRateBps),
                icon: "arrow.down.circle.fill",
                color: .blue
            )
            statTile(
                title: "Отправлено",
                value: ByteFormat.string(stats.txBytes),
                rate: ByteFormat.rate(stats.txRateBps),
                icon: "arrow.up.circle.fill",
                color: .green
            )
        }
    }

    private func statTile(title: String, value: String, rate: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(.system(.title3, design: .rounded, weight: .semibold))
                .monospacedDigit()
            Text(rate)
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }
}
