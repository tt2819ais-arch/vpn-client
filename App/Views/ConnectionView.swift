import SwiftUI

struct ConnectionView: View {
    @EnvironmentObject private var appViewModel: AppViewModel

    var body: some View {
        NavigationStack {
            ZStack {
                // Pure-black canvas + drifting stars + slow aurora — same
                // visual language as the splash, dialled down so it doesn't
                // fight the foreground.
                Color.black.ignoresSafeArea()
                StarfieldView(density: 0.00009, speed: 10...40, aurora: true)
                    .opacity(0.85)
                    .ignoresSafeArea()

                // TimelineView ticks every second, regardless of tab.
                TimelineView(.periodic(from: Date(), by: 1)) { context in
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 22) {
                            statusHeader(now: context.date)
                            bigToggle
                            if let server = appViewModel.selectedServer {
                                currentServerCard(server)
                            }
                            statsGrid
                            telegramFooter
                            Spacer(minLength: 24)
                        }
                        .padding(.horizontal, 18)
                        .padding(.top, 6)
                    }
                }
            }
            .preferredColorScheme(.dark)
            .toolbarBackground(.hidden, for: .navigationBar)
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
            Text(appViewModel.connection.state.localizedTitle.uppercased())
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .tracking(2)
                .foregroundStyle(Color.white.opacity(0.7))

            if let since = appViewModel.connection.connectedSince,
               appViewModel.connection.state == .connected {
                Text(ByteFormat.duration(now.timeIntervalSince(since)))
                    .font(.system(size: 56, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
                    .shadow(color: Color.black.opacity(0.5), radius: 6)
            } else {
                Text("00:00")
                    .font(.system(size: 56, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Color.white.opacity(0.35))
                    .shadow(color: Color.black.opacity(0.5), radius: 6)
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
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .foregroundStyle(.white)
                    Text("\(server.address) · :\(server.port)")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Color.white.opacity(0.55))
                }
                Spacer()
                pingBadge(for: server)
            }
            .padding(14)
            if let country = appViewModel.country {
                Divider().background(Color.white.opacity(0.1)).padding(.leading, 14)
                HStack(spacing: 8) {
                    Image(systemName: "globe")
                        .foregroundStyle(Color.white.opacity(0.7))
                    Text(country)
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                        .foregroundStyle(.white)
                    Spacer()
                    Button {
                        Task { await appViewModel.refreshCountry() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.subheadline.bold())
                            .foregroundStyle(.white)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }
        }
        .glassCard()
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
                    ProgressView().controlSize(.small).tint(.white)
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
            .font(.system(.footnote, design: .rounded, weight: .heavy))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule().fill(pingColor(for: result?.latencyMs).opacity(0.2))
            )
            .overlay(
                Capsule().strokeBorder(pingColor(for: result?.latencyMs).opacity(0.45), lineWidth: 1)
            )
            .foregroundStyle(pingColor(for: result?.latencyMs))
        }
        .buttonStyle(.plain)
    }

    private func pingColor(for ms: Int?) -> Color {
        guard let ms else { return Color.white.opacity(0.6) }
        switch ms {
        case 0..<80:    return Color(red: 0.45, green: 0.92, blue: 0.66)   // mint
        case 80..<180:  return Color(red: 1.0, green: 0.82, blue: 0.35)    // amber
        default:        return Color(red: 1.0, green: 0.42, blue: 0.42)    // coral
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
                color: Color(red: 0.45, green: 0.78, blue: 1.0)
            )
            statTile(
                title: "Отправлено",
                value: ByteFormat.string(stats.txBytes),
                rate: ByteFormat.rate(stats.txRateBps),
                icon: "arrow.up.circle.fill",
                color: Color(red: 0.45, green: 0.92, blue: 0.66)
            )
        }
    }

    private func statTile(title: String, value: String, rate: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Text(title)
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.85))
            }
            Text(value)
                .font(.system(.title3, design: .rounded, weight: .heavy))
                .monospacedDigit()
                .foregroundStyle(.white)
            Text(rate)
                .font(.system(.caption, design: .rounded, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.6))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .glassCard(cornerRadius: 16)
    }

    private var telegramFooter: some View {
        VStack(spacing: 6) {
            Text("Остались вопросы?")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.65))

            Link(destination: URL(string: "https://t.me/MaksimXyila")!) {
                HStack(spacing: 8) {
                    TelegramGlyph()
                        .frame(width: 22, height: 22)
                    Text("@MaksimXyila")
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(
                    Capsule(style: .continuous)
                        .fill(.ultraThinMaterial)
                )
                .overlay(
                    Capsule(style: .continuous)
                        .strokeBorder(Color.white.opacity(0.22), lineWidth: 1)
                )
            }
            .simultaneousGesture(TapGesture().onEnded {
                LogStore.shared.info("Footer Telegram link tapped", tag: "User")
            })
        }
        .padding(.top, 12)
    }
}
