import Foundation
import SwiftUI

public enum AppTheme: String, Codable, CaseIterable, Identifiable, Sendable {
    case system, light, dark
    public var id: String { rawValue }

    public var localizedTitle: String {
        switch self {
        case .system: return "Системная"
        case .light:  return "Светлая"
        case .dark:   return "Тёмная"
        }
    }

    public var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }
}

public enum PingProtocol: String, Codable, CaseIterable, Identifiable, Sendable {
    case tcp        = "tcp"
    case httpGet    = "get"
    case httpHead   = "head"
    case icmp       = "icmp"

    public var id: String { rawValue }

    public var localizedTitle: String {
        switch self {
        case .tcp:      return "TCP"
        case .httpGet:  return "HTTP GET"
        case .httpHead: return "HTTP HEAD"
        case .icmp:     return "ICMP"
        }
    }

    public var subtitle: String {
        switch self {
        case .tcp:      return "TCP handshake до сервера"
        case .httpGet:  return "GET через прокси на gstatic.com"
        case .httpHead: return "HEAD через прокси на gstatic.com"
        case .icmp:     return "Системный ping (требует разрешения сети)"
        }
    }
}

public struct AppSettings: Codable, Equatable, Sendable {
    public var theme: AppTheme = .system
    public var pingProtocol: PingProtocol = .tcp
    public var hapticsEnabled: Bool = true
    public var autoReconnect: Bool = true
    public var killSwitch: Bool = false
    public var selectedServerID: UUID? = nil

    public static let `default` = AppSettings()

    public init(
        theme: AppTheme = .system,
        pingProtocol: PingProtocol = .tcp,
        hapticsEnabled: Bool = true,
        autoReconnect: Bool = true,
        killSwitch: Bool = false,
        selectedServerID: UUID? = nil
    ) {
        self.theme = theme
        self.pingProtocol = pingProtocol
        self.hapticsEnabled = hapticsEnabled
        self.autoReconnect = autoReconnect
        self.killSwitch = killSwitch
        self.selectedServerID = selectedServerID
    }
}
