import Foundation
import NetworkExtension
import Combine

/// High-level facade around `NETunnelProviderManager`.
@MainActor
public final class VPNManager: ObservableObject {

    public static let shared = VPNManager()

    @Published public private(set) var state: ConnectionState = .disconnected

    private var manager: NETunnelProviderManager?
    private var observer: NSObjectProtocol?

    public init() {
        observer = NotificationCenter.default.addObserver(
            forName: .NEVPNStatusDidChange,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let conn = note.object as? NEVPNConnection else { return }
            Task { @MainActor [weak self] in
                self?.update(from: conn.status)
            }
        }
    }

    deinit {
        if let observer { NotificationCenter.default.removeObserver(observer) }
    }

    // MARK: – Public API

    public func refresh() async {
        do {
            let managers = try await NETunnelProviderManager.loadAllFromPreferences()
            self.manager = managers.first
            if let session = manager?.connection {
                update(from: session.status)
            } else {
                state = .disconnected
            }
        } catch {
            state = .failed
        }
    }

    public func connect(to server: Server) async throws {
        state = .connecting
        let manager = try await loadOrCreateManager(for: server)
        manager.isEnabled = true
        try await manager.saveToPreferences()
        try await manager.loadFromPreferences()
        self.manager = manager
        do {
            try manager.connection.startVPNTunnel(options: [
                "serverID": server.id.uuidString as NSString
            ])
        } catch {
            state = .failed
            throw error
        }
    }

    public func disconnect() async throws {
        state = .disconnecting
        manager?.connection.stopVPNTunnel()
    }

    public func fetchStats() async -> TrafficStats? {
        guard let session = manager?.connection as? NETunnelProviderSession else { return nil }
        return await withCheckedContinuation { continuation in
            do {
                try session.sendProviderMessage(Data("stats".utf8)) { data in
                    if let data, let stats = try? JSONDecoder().decode(TrafficStats.self, from: data) {
                        continuation.resume(returning: stats)
                    } else {
                        continuation.resume(returning: nil)
                    }
                }
            } catch {
                continuation.resume(returning: nil)
            }
        }
    }

    // MARK: – Helpers

    private func loadOrCreateManager(for server: Server) async throws -> NETunnelProviderManager {
        let managers = try await NETunnelProviderManager.loadAllFromPreferences()
        let manager = managers.first ?? NETunnelProviderManager()

        let proto = NETunnelProviderProtocol()
        proto.providerBundleIdentifier = "com.tt2819ais.vpnclient.tunnel"
        proto.serverAddress = "\(server.address):\(server.port)"
        proto.providerConfiguration = [
            "serverID": server.id.uuidString,
            "serverJSON": (try? JSONEncoder().encode(server)) ?? Data()
        ]
        proto.disconnectOnSleep = false

        manager.protocolConfiguration = proto
        manager.localizedDescription = "VPN Client"
        manager.isEnabled = true
        manager.onDemandRules = []
        return manager
    }

    private func update(from status: NEVPNStatus) {
        switch status {
        case .invalid:        state = .disconnected
        case .disconnected:   state = .disconnected
        case .connecting:     state = .connecting
        case .connected:      state = .connected
        case .reasserting:    state = .reconnecting
        case .disconnecting:  state = .disconnecting
        @unknown default:     state = .disconnected
        }
    }
}
