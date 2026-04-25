import SwiftUI

struct ConnectionView: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    @State private var now: Date = Date()

    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    statusHeader
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
            .navigationTitle("VPN Client")
            .navigationBarTitleDisplayMode(.inline)
            .onReceive(ticker) { date in self.now = date }
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

    private var statusHeader: some View {
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
        Button {
            Task { await appViewModel.toggleConnection() }
        } label: {
            ZStack {
                Circle()
                    .fill(toggleGradient)
                    .frame(width: 200, height: 200)
                    .shadow(color: toggleShadow, radius: 24, y: 4)

                if appViewModel.connection.state == .connecting ||
                   appViewModel.connection.state == .reconnecting ||
                   appViewModel.connection.state == .disconnecting {
                    ProgressView()
                        .controlSize(.large)
                        .tint(.white)
                } else {
                    Image(systemName: appViewModel.connection.state.isActive
                          ? "power.circle.fill"
                          : "power")
                        .font(.system(size: 80, weight: .light))
                        .foregroundStyle(.white)
                        .symbolRenderingMode(.hierarchical)
                }
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(appViewModel.connection.state.isActive ? 1.0 : 0.97)
        .animation(.spring(response: 0.4, dampingFraction: 0.7),
                   value: appViewModel.connection.state)
    }

    private var toggleGradient: LinearGradient {
        let colors: [Color]
        switch appViewModel.connection.state {
        case .connected:
            colors = [Color(red: 0.20, green: 0.78, blue: 0.46),
                      Color(red: 0.10, green: 0.55, blue: 0.40)]
        case .connecting, .reconnecting:
            colors = [Color.orange, Color(red: 0.85, green: 0.40, blue: 0.10)]
        case .failed:
            colors = [Color(red: 0.92, green: 0.30, blue: 0.30),
                      Color(red: 0.65, green: 0.15, blue: 0.15)]
        default:
            colors = [Color.accentColor.opacity(0.95),
                      Color.accentColor.opacity(0.75)]
        }
        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    private var toggleShadow: Color {
        appViewModel.connection.state.isActive
            ? Color.green.opacity(0.45)
            : Color.accentColor.opacity(0.30)
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
