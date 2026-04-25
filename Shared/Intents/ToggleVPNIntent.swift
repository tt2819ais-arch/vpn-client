import AppIntents
import Foundation
import NetworkExtension

/// Self-contained `AppIntent` used by widget toggle buttons. Lives in `Shared/`
/// so both the main app and the widget extension compile it.
///
/// NOTE: NETunnelProviderManager APIs are used directly here so that the
/// widget process can drive the toggle without depending on UI types.
public struct ToggleVPNIntent: AppIntent {
    public static var title: LocalizedStringResource = "Переключить VPN"
    public static var description = IntentDescription("Включает или отключает VPN-туннель.")
    public static var openAppWhenRun: Bool = false

    public init() {}

    public func perform() async throws -> some IntentResult {
        let managers = try await NETunnelProviderManager.loadAllFromPreferences()

        if let manager = managers.first {
            switch manager.connection.status {
            case .connected, .connecting, .reasserting:
                manager.connection.stopVPNTunnel()
                return .result()
            default:
                try manager.connection.startVPNTunnel()
                return .result()
            }
        }

        // No existing configuration — bootstrap one from the selected server.
        let store = AppGroup.defaults.decoded([Server].self, for: .servers) ?? Server.bundled
        let settings = AppGroup.defaults.decoded(AppSettings.self, for: .settings) ?? .default
        let server = store.first(where: { $0.id == settings.selectedServerID }) ?? store.first
        guard let server else {
            throw NSError(domain: "ToggleVPNIntent", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "No server configured"])
        }

        let manager = NETunnelProviderManager()
        let proto = NETunnelProviderProtocol()
        proto.providerBundleIdentifier = "com.tt2819ais.vpnclient.tunnel"
        proto.serverAddress = "\(server.address):\(server.port)"
        proto.providerConfiguration = [
            "serverID": server.id.uuidString,
            "serverJSON": (try? JSONEncoder().encode(server)) ?? Data()
        ]
        manager.protocolConfiguration = proto
        manager.localizedDescription = "VPN Client"
        manager.isEnabled = true

        try await manager.saveToPreferences()
        try await manager.loadFromPreferences()
        try manager.connection.startVPNTunnel()
        return .result()
    }
}

/// Foreground-launching intent — used by Lock Screen rectangular widget.
public struct OpenAppIntent: AppIntent {
    public static var title: LocalizedStringResource = "Открыть VPN Client"
    public static var openAppWhenRun: Bool = true
    public init() {}
    public func perform() async throws -> some IntentResult { .result() }
}
