import Foundation

/// Routing mode for a server profile.
public enum RoutingMode: String, Codable, CaseIterable, Identifiable, Sendable {
    /// All traffic flows through the proxy outbound (classic full-tunnel VPN).
    case proxyAll = "proxy_all"
    /// Russian whitelist domains routed `direct`, everything else through `proxy`.
    /// Used to bypass TSPU-style "white list" filtering.
    case bypassWhitelist = "bypass_whitelist"

    public var id: String { rawValue }

    public var localizedTitle: String {
        switch self {
        case .proxyAll:        return "Весь трафик через VPN"
        case .bypassWhitelist: return "Обход белых списков (ТСПУ)"
        }
    }
}

/// VLESS+Reality profile for one upstream Xray inbound.
public struct Server: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var flagEmoji: String
    public var countryCode: String         // ISO 3166-1 alpha-2 (e.g. "RU")
    public var address: String
    public var port: Int
    public var uuid: String                // VLESS user id
    public var flow: String                // typically "xtls-rprx-vision"
    public var publicKey: String           // Reality public key (base64)
    public var shortId: String
    public var serverName: String          // SNI / Reality server name
    public var fingerprint: String         // typically "chrome"
    public var spiderX: String?
    public var routing: RoutingMode
    public var note: String?

    public init(
        id: UUID = UUID(),
        name: String,
        flagEmoji: String = "🇷🇺",
        countryCode: String = "RU",
        address: String,
        port: Int,
        uuid: String,
        flow: String = "xtls-rprx-vision",
        publicKey: String,
        shortId: String,
        serverName: String,
        fingerprint: String = "chrome",
        spiderX: String? = nil,
        routing: RoutingMode = .proxyAll,
        note: String? = nil
    ) {
        self.id = id
        self.name = name
        self.flagEmoji = flagEmoji
        self.countryCode = countryCode
        self.address = address
        self.port = port
        self.uuid = uuid
        self.flow = flow
        self.publicKey = publicKey
        self.shortId = shortId
        self.serverName = serverName
        self.fingerprint = fingerprint
        self.spiderX = spiderX
        self.routing = routing
        self.note = note
    }
}

public extension Server {
    /// Default servers shipped with the app — three VLESS+Reality inbounds on 2.26.53.100.
    /// IDs are deterministic so they remain stable across launches and across
    /// the app + extensions + widgets.
    static let bundled: [Server] = [
        Server(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            name: "Россия #1 — Yandex SNI",
            address: "2.26.53.100",
            port: 443,
            uuid: "eb208d5a-9438-4400-b000-058288c3b1b1",
            publicKey: "DOUMGEh9tPjkaVgbq5FuEpbnEzzCnbFTsIJF8nEjVR4",
            shortId: "6ee75049e018a62a",
            serverName: "www.yandex.ru",
            routing: .proxyAll,
            note: "Стандартный full-tunnel VPN"
        ),
        Server(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
            name: "Россия #2 — VK SNI",
            address: "2.26.53.100",
            port: 4443,
            uuid: "eb208d5a-9438-4400-b000-058288c3b1b1",
            publicKey: "DOUMGEh9tPjkaVgbq5FuEpbnEzzCnbFTsIJF8nEjVR4",
            shortId: "6ee75049e018a62a",
            serverName: "vk.com",
            routing: .proxyAll,
            note: "Стандартный full-tunnel VPN"
        ),
        Server(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
            name: "Обход белых списков ⚡️",
            address: "2.26.53.100",
            port: 2096,
            uuid: "eb208d5a-9438-4400-b000-058288c3b1b1",
            publicKey: "DOUMGEh9tPjkaVgbq5FuEpbnEzzCnbFTsIJF8nEjVR4",
            shortId: "6ee75049e018a62a",
            serverName: "www.avito.ru",
            routing: .bypassWhitelist,
            note: "RU-домены идут direct, всё остальное через прокси"
        )
    ]
}
