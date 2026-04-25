import Foundation

/// Shared App Group identifier — must match the entitlement value in
/// App/VPNClient.entitlements, PacketTunnel/PacketTunnel.entitlements,
/// and Widget/Widget.entitlements.
public enum AppGroup {
    public static let identifier = "group.com.tt2819ais.vpnclient"

    public static var defaults: UserDefaults {
        guard let suite = UserDefaults(suiteName: identifier) else {
            assertionFailure("Failed to open UserDefaults suite \(identifier). Check App Group entitlement.")
            return .standard
        }
        return suite
    }

    /// Shared container URL for log files / xray data dir.
    public static var containerURL: URL {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)
            ?? FileManager.default.temporaryDirectory
    }
}

/// Type-safe wrappers around the shared `UserDefaults` suite.
/// Both the main app (UI) and the PacketTunnelProvider read/write through this.
public enum SharedKey: String {
    case servers              = "vpnclient.servers"
    case settings             = "vpnclient.settings"
    case connectionInfo       = "vpnclient.connection"
    case lastPings            = "vpnclient.lastPings"
    case lastCountryLookup    = "vpnclient.lastCountry"
}

public extension UserDefaults {
    func encoded<T: Encodable>(_ value: T, for key: SharedKey) {
        do {
            let data = try JSONEncoder().encode(value)
            set(data, forKey: key.rawValue)
        } catch {
            assertionFailure("Failed to encode \(key.rawValue): \(error)")
        }
    }

    func decoded<T: Decodable>(_ type: T.Type, for key: SharedKey) -> T? {
        guard let data = data(forKey: key.rawValue) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}
