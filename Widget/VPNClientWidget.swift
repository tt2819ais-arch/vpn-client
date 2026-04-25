import WidgetKit
import SwiftUI
import AppIntents

@main
struct VPNClientWidgetBundle: WidgetBundle {
    var body: some Widget {
        VPNStatusWidget()
        VPNStatusLockScreenWidget()
    }
}

// MARK: – Provider

struct VPNStatusEntry: TimelineEntry {
    let date: Date
    let connection: ConnectionInfo
    let serverName: String
    let countryFlag: String
}

struct VPNStatusProvider: TimelineProvider {
    func placeholder(in context: Context) -> VPNStatusEntry {
        VPNStatusEntry(
            date: .now,
            connection: ConnectionInfo(state: .connected, serverID: nil,
                                       connectedSince: Date().addingTimeInterval(-3600), stats: .init()),
            serverName: "Россия #1",
            countryFlag: "🇷🇺"
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (VPNStatusEntry) -> Void) {
        completion(currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<VPNStatusEntry>) -> Void) {
        let entry = currentEntry()
        // Refresh every 30 seconds while connected, every 5 minutes when idle.
        let next = entry.connection.state.isActive
            ? Date().addingTimeInterval(30)
            : Date().addingTimeInterval(300)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    private func currentEntry() -> VPNStatusEntry {
        let info = AppGroup.defaults.decoded(ConnectionInfo.self, for: .connectionInfo)
            ?? .disconnected

        let servers = AppGroup.defaults.decoded([Server].self, for: .servers) ?? Server.bundled
        let server = info.serverID.flatMap { id in servers.first(where: { $0.id == id }) }
            ?? servers.first

        return VPNStatusEntry(
            date: .now,
            connection: info,
            serverName: server?.name ?? "—",
            countryFlag: server?.flagEmoji ?? "🌐"
        )
    }
}

// MARK: – Widget definitions

struct VPNStatusWidget: Widget {
    let kind = "VPNStatusWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: VPNStatusProvider()) { entry in
            VPNStatusWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("VPN Client")
        .description("Статус подключения и быстрый toggle.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct VPNStatusLockScreenWidget: Widget {
    let kind = "VPNStatusLockScreenWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: VPNStatusProvider()) { entry in
            VPNStatusLockScreenView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("VPN")
        .description("Статус VPN на экране блокировки.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

// MARK: – Views

struct VPNStatusWidgetView: View {
    let entry: VPNStatusEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .systemSmall:  smallBody
        default:            mediumBody
        }
    }

    private var smallBody: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(entry.countryFlag).font(.system(size: 22))
                Spacer()
                Image(systemName: entry.connection.state.isActive
                      ? "shield.lefthalf.filled" : "shield")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(entry.connection.state.isActive ? .green : .secondary)
            }

            Text(entry.connection.state.localizedTitle)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(entry.serverName)
                .font(.system(.callout, design: .rounded, weight: .semibold))
                .lineLimit(2)

            Spacer(minLength: 0)

            if let since = entry.connection.connectedSince, entry.connection.state.isActive {
                Text(since, style: .timer)
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(.green)
            }

            ToggleButton(state: entry.connection.state)
        }
    }

    private var mediumBody: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(entry.countryFlag).font(.title2)
                    Text(entry.serverName)
                        .font(.system(.headline, design: .rounded))
                        .lineLimit(1)
                }
                Text(entry.connection.state.localizedTitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let since = entry.connection.connectedSince, entry.connection.state.isActive {
                    Label {
                        Text(since, style: .timer).monospacedDigit()
                    } icon: {
                        Image(systemName: "clock")
                    }
                    .font(.caption)
                    .foregroundStyle(.green)
                }
                HStack(spacing: 12) {
                    Label(ByteFormat.string(entry.connection.stats.rxBytes), systemImage: "arrow.down")
                    Label(ByteFormat.string(entry.connection.stats.txBytes), systemImage: "arrow.up")
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
            Spacer()
            ToggleButton(state: entry.connection.state)
        }
    }
}

struct ToggleButton: View {
    let state: ConnectionState

    var body: some View {
        Button(intent: ToggleVPNIntent()) {
            HStack(spacing: 6) {
                Image(systemName: state.isActive ? "stop.fill" : "play.fill")
                Text(state.isActive ? "Стоп" : "Старт")
            }
            .font(.system(.caption, design: .rounded, weight: .bold))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule().fill(state.isActive ? Color.red.opacity(0.18) : Color.green.opacity(0.18))
            )
            .foregroundStyle(state.isActive ? .red : .green)
        }
        .buttonStyle(.plain)
    }
}

struct VPNStatusLockScreenView: View {
    let entry: VPNStatusEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryCircular:
            ZStack {
                Circle().stroke(.tertiary, lineWidth: 2)
                Image(systemName: entry.connection.state.isActive
                      ? "shield.lefthalf.filled" : "shield.slash")
                    .font(.system(size: 22))
                    .foregroundStyle(entry.connection.state.isActive ? .green : .red)
            }
        case .accessoryRectangular:
            VStack(alignment: .leading) {
                HStack {
                    Image(systemName: entry.connection.state.isActive
                          ? "shield.lefthalf.filled" : "shield")
                    Text(entry.connection.state.localizedTitle)
                        .font(.headline)
                }
                Text(entry.serverName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if let since = entry.connection.connectedSince, entry.connection.state.isActive {
                    Text(since, style: .timer)
                        .font(.caption2)
                        .monospacedDigit()
                }
            }
        case .accessoryInline:
            Label {
                Text("\(entry.serverName) · \(entry.connection.state.localizedTitle)")
            } icon: {
                Image(systemName: entry.connection.state.isActive
                      ? "shield.lefthalf.filled" : "shield")
            }
        default:
            Image(systemName: "shield")
        }
    }
}
