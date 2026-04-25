import Foundation

public enum ConnectionState: String, Codable, Sendable {
    case disconnected
    case connecting
    case connected
    case reconnecting
    case disconnecting
    case failed

    public var isActive: Bool {
        switch self {
        case .connected, .connecting, .reconnecting: return true
        case .disconnected, .disconnecting, .failed:  return false
        }
    }

    public var localizedTitle: String {
        switch self {
        case .disconnected:  return "Отключено"
        case .connecting:    return "Подключение…"
        case .connected:     return "Подключено"
        case .reconnecting:  return "Переподключение…"
        case .disconnecting: return "Отключение…"
        case .failed:        return "Ошибка"
        }
    }
}

public struct TrafficStats: Codable, Equatable, Sendable {
    public var rxBytes: UInt64 = 0
    public var txBytes: UInt64 = 0
    public var rxRateBps: UInt64 = 0
    public var txRateBps: UInt64 = 0

    public static let zero = TrafficStats()

    public init(rxBytes: UInt64 = 0, txBytes: UInt64 = 0, rxRateBps: UInt64 = 0, txRateBps: UInt64 = 0) {
        self.rxBytes = rxBytes
        self.txBytes = txBytes
        self.rxRateBps = rxRateBps
        self.txRateBps = txRateBps
    }
}

public struct ConnectionInfo: Codable, Equatable, Sendable {
    public var state: ConnectionState
    public var serverID: UUID?
    public var connectedSince: Date?
    public var stats: TrafficStats

    public static let disconnected = ConnectionInfo(
        state: .disconnected,
        serverID: nil,
        connectedSince: nil,
        stats: .zero
    )

    public init(
        state: ConnectionState,
        serverID: UUID?,
        connectedSince: Date?,
        stats: TrafficStats
    ) {
        self.state = state
        self.serverID = serverID
        self.connectedSince = connectedSince
        self.stats = stats
    }
}

public enum ByteFormat {
    /// Compact ru-RU byte formatter (e.g. "12,3 МБ").
    public static func string(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .binary
        formatter.includesUnit = true
        formatter.includesCount = true
        return formatter.string(fromByteCount: Int64(bytes))
    }

    public static func rate(_ bytesPerSecond: UInt64) -> String {
        string(bytesPerSecond) + "/с"
    }

    public static func duration(_ interval: TimeInterval) -> String {
        let seconds = Int(interval)
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        if h > 0 {
            return String(format: "%02d:%02d:%02d", h, m, s)
        }
        return String(format: "%02d:%02d", m, s)
    }
}
