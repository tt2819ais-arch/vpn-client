import NetworkExtension
import Foundation
import os.log

/// `NEPacketTunnelProvider` that delegates to the bundled `XrayController`.
/// The provider speaks SOCKS/HTTP through xray-core (libXray) on 127.0.0.1.
final class PacketTunnelProvider: NEPacketTunnelProvider {

    private let log = OSLog(subsystem: "com.tt2819ais.vpnclient.tunnel", category: "tunnel")
    private let xray = XrayController()
    private var server: Server?
    private var startedAt: Date?

    override func startTunnel(options: [String: NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        os_log("startTunnel", log: log, type: .info)
        Task {
            do {
                try await self.startTunnelInternal()
                completionHandler(nil)
            } catch {
                os_log("startTunnel failed: %{public}@", log: log, type: .error, "\(error)")
                completionHandler(error)
            }
        }
    }

    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        os_log("stopTunnel reason=%{public}d", log: log, type: .info, reason.rawValue)
        xray.stop()
        startedAt = nil

        let info = ConnectionInfo(state: .disconnected, serverID: nil,
                                  connectedSince: nil, stats: .zero)
        AppGroup.defaults.encoded(info, for: .connectionInfo)
        completionHandler()
    }

    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
        let cmd = String(data: messageData, encoding: .utf8) ?? ""
        switch cmd {
        case "stats":
            let stats = xray.queryStats()
            completionHandler?(try? JSONEncoder().encode(stats))
        case "ping":
            completionHandler?("pong".data(using: .utf8))
        default:
            completionHandler?(nil)
        }
    }

    override func sleep(completionHandler: @escaping () -> Void) {
        // Keep tunnel alive while device sleeps.
        completionHandler()
    }

    override func wake() {}

    // MARK: – Internals

    private func startTunnelInternal() async throws {
        guard let proto = self.protocolConfiguration as? NETunnelProviderProtocol,
              let dict = proto.providerConfiguration,
              let serverData = dict["serverJSON"] as? Data,
              let server = try? JSONDecoder().decode(Server.self, from: serverData) else {
            throw NSError(domain: "PacketTunnelProvider", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Missing or invalid server config"])
        }
        self.server = server

        LogStore.shared.info("Tunnel start requested for \(server.name) @ \(server.address):\(server.port)", tag: "Tunnel")

        // CRITICAL: we must NOT install tunnel network settings if the xray
        // engine isn't available — otherwise iOS routes all traffic into a
        // black hole and the user's internet just dies. Refuse early.
        guard xray.isAvailable else {
            LogStore.shared.error("Refusing to start tunnel: libXray binary is not bundled", tag: "Tunnel")
            throw NSError(domain: "PacketTunnelProvider", code: 100,
                          userInfo: [NSLocalizedDescriptionKey: "VPN-движок (libXray) не подключён к сборке. Tunnel не запущен, чтобы не сломать интернет. См. логи."])
        }

        // Start xray-core FIRST so the local SOCKS/HTTP inbounds are listening
        // before iOS hands traffic to the proxy. If xray fails, we abort
        // *before* committing tunnel settings so the user's internet stays
        // healthy.
        let dataDir = AppGroup.containerURL.appendingPathComponent("xray", isDirectory: true)
        try? FileManager.default.createDirectory(at: dataDir, withIntermediateDirectories: true)

        let configJSON = try XrayConfigBuilder.jsonString(for: server, dataDir: dataDir)
        LogStore.shared.debug("xray config size: \(configJSON.count) bytes", tag: "Tunnel")
        try xray.start(configJSON: configJSON, dataDir: dataDir)
        LogStore.shared.info("xray inbound: socks=127.0.0.1:10808 http=127.0.0.1:10809", tag: "Tunnel")

        // Build network settings.
        // We do NOT install a default IPv4 route — that would capture every
        // packet at the IP layer, but we don't have a tun2socks bridge to
        // forward those packets to xray, so they would fall into a black
        // hole and the user's internet would die. Instead we use proxy
        // mode: iOS routes HTTP/HTTPS-aware app traffic to xray's local
        // HTTP inbound on 127.0.0.1:10809.
        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: server.address)
        settings.mtu = 1400

        let ipv4 = NEIPv4Settings(addresses: ["198.18.0.2"], subnetMasks: ["255.255.255.255"])
        ipv4.includedRoutes = []   // intentionally empty — see comment above
        ipv4.excludedRoutes = [NEIPv4Route.default()]
        settings.ipv4Settings = ipv4

        let dns = NEDNSSettings(servers: ["1.1.1.1", "8.8.8.8"])
        dns.matchDomains = [""]
        settings.dnsSettings = dns

        let proxy = NEProxySettings()
        proxy.httpEnabled = true
        proxy.httpServer = NEProxyServer(address: "127.0.0.1", port: 10809)
        proxy.httpsEnabled = true
        proxy.httpsServer = NEProxyServer(address: "127.0.0.1", port: 10809)
        proxy.matchDomains = [""]
        proxy.excludeSimpleHostnames = false
        settings.proxySettings = proxy

        try await applyTunnelSettings(settings)
        LogStore.shared.info("Tunnel network settings installed (proxy mode)", tag: "Tunnel")
        self.startedAt = Date()

        let info = ConnectionInfo(state: .connected, serverID: server.id,
                                  connectedSince: Date(), stats: .zero)
        AppGroup.defaults.encoded(info, for: .connectionInfo)
    }

    private func applyTunnelSettings(_ settings: NETunnelNetworkSettings?) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            self.setTunnelNetworkSettings(settings) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }
}
