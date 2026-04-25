import Foundation
import Combine
import SwiftUI

@MainActor
final class AppViewModel: ObservableObject {
    @Published var selectedTab: AppTab = .connection
    @Published var settings: AppSettings {
        didSet { persistSettings() }
    }
    @Published var connection: ConnectionInfo = .disconnected
    @Published var pings: [UUID: PingResult] = [:]
    @Published var pingingServerIDs: Set<UUID> = []
    @Published var country: String? = nil
    @Published var lastError: String? = nil

    let serverStore: ServerStore
    let vpnManager: VPNManager
    let pingService = PingService()
    let countryService = CountryLookupService()
    let haptics = HapticsService()

    private var cancellables = Set<AnyCancellable>()
    private var statsTimer: Timer?
    /// Timestamp when the last `connect()` started — used to detect fast
    /// flaps (connecting → disconnected within 2s = tunnel-side failure).
    private var lastConnectStartedAt: Date?

    init(
        serverStore: ServerStore = .shared,
        vpnManager: VPNManager = .shared
    ) {
        self.serverStore = serverStore
        self.vpnManager = vpnManager

        let stored = AppGroup.defaults.decoded(AppSettings.self, for: .settings) ?? .default
        self.settings = stored

        LogStore.shared.info("App launched. \(serverStore.servers.count) servers loaded. theme=\(stored.theme.rawValue) ping=\(stored.pingProtocol.rawValue)", tag: "App")

        bindVPNManager()
        loadPersistedConnection()
        startStatsTimer()

        Task { await vpnManager.refresh() }
    }

    // MARK: – Public actions

    var selectedServer: Server? {
        if let id = settings.selectedServerID {
            return serverStore.server(with: id)
        }
        return serverStore.servers.first
    }

    func toggleConnection() async {
        haptics.tap(.medium, enabled: settings.hapticsEnabled)
        guard let server = selectedServer else {
            LogStore.shared.warn("Toggle pressed without a selected server", tag: "User")
            lastError = "Сначала выберите сервер"
            haptics.notify(.error, enabled: settings.hapticsEnabled)
            return
        }

        do {
            if connection.state.isActive {
                LogStore.shared.info("User pressed: DISCONNECT (\(server.name))", tag: "User")
                try await vpnManager.disconnect()
                haptics.notify(.success, enabled: settings.hapticsEnabled)
                LogStore.shared.info("Disconnected successfully", tag: "VPN")
            } else {
                LogStore.shared.info("User pressed: CONNECT to \(server.name) [\(server.address):\(server.port)]", tag: "User")
                lastConnectStartedAt = Date()
                try await vpnManager.connect(to: server)
                haptics.notify(.success, enabled: settings.hapticsEnabled)
                LogStore.shared.info("Connect call returned, awaiting state", tag: "VPN")
                Task { await refreshCountry() }
            }
        } catch {
            haptics.notify(.error, enabled: settings.hapticsEnabled)
            lastError = error.localizedDescription
            LogStore.shared.error("VPN toggle failed: \(error.localizedDescription)", tag: "VPN")
        }
    }

    func selectServer(_ server: Server) async {
        haptics.tap(.light, enabled: settings.hapticsEnabled)
        LogStore.shared.info("User selected server: \(server.name)", tag: "User")
        settings.selectedServerID = server.id
        if connection.state.isActive {
            do {
                LogStore.shared.info("Reconnecting to new server while active", tag: "VPN")
                try await vpnManager.connect(to: server)
            } catch {
                lastError = error.localizedDescription
                LogStore.shared.error("Reconnect failed: \(error.localizedDescription)", tag: "VPN")
            }
        }
    }

    func ping(_ server: Server) async {
        haptics.tap(.light, enabled: settings.hapticsEnabled)
        let proto = settings.pingProtocol
        LogStore.shared.info("Ping start \(proto.rawValue) -> \(server.name) [\(server.address):\(server.port)]", tag: "Ping")
        pingingServerIDs.insert(server.id)
        defer { pingingServerIDs.remove(server.id) }
        let result = await pingService.ping(server: server, protocol: proto)
        pings[server.id] = result
        if let ms = result.latencyMs {
            LogStore.shared.info("Ping result \(proto.rawValue) -> \(server.name): \(ms) ms", tag: "Ping")
        } else {
            let reason = result.error ?? "unknown"
            LogStore.shared.warn("Ping failed \(proto.rawValue) -> \(server.name): \(reason)", tag: "Ping")
        }
        haptics.notify(result.isSuccess ? .success : .error,
                       enabled: settings.hapticsEnabled)
    }

    func pingAll() async {
        for server in serverStore.servers {
            await ping(server)
        }
    }

    func refreshCountry() async {
        country = await countryService.lookup()
    }

    // MARK: – Persistence

    private func persistSettings() {
        AppGroup.defaults.encoded(settings, for: .settings)
    }

    private func loadPersistedConnection() {
        if let info = AppGroup.defaults.decoded(ConnectionInfo.self, for: .connectionInfo) {
            self.connection = info
        }
    }

    // MARK: – VPN binding

    private func bindVPNManager() {
        vpnManager.$state
            .receive(on: RunLoop.main)
            .sink { [weak self] state in
                guard let self else { return }
                let previous = self.connection.state
                if previous != state {
                    LogStore.shared.info("VPN state -> \(state.rawValue)", tag: "VPN")
                }
                self.connection.state = state
                if state == .connected, self.connection.connectedSince == nil {
                    self.connection.connectedSince = Date()
                    self.lastConnectStartedAt = nil
                }
                if !state.isActive {
                    self.connection.connectedSince = nil
                    self.connection.stats = .zero
                }
                AppGroup.defaults.encoded(self.connection, for: .connectionInfo)

                // Tunnel-side failure detection: if we transitioned
                // connecting → disconnected within 2 seconds of the user
                // pressing connect, the extension threw on startup. iOS
                // doesn't surface that error to the host app, so we surface
                // it ourselves.
                if previous == .connecting, state == .disconnected,
                   let started = self.lastConnectStartedAt,
                   Date().timeIntervalSince(started) < 2.0 {
                    self.lastConnectStartedAt = nil
                    let msg = "VPN-туннель не запустился. Скорее всего, libXray не подключён к сборке (см. логи Tunnel)."
                    self.lastError = msg
                    LogStore.shared.error("Fast flap detected (\(String(format: "%.2f", Date().timeIntervalSince(started)))s) — surfacing tunnel failure", tag: "VPN")
                    self.haptics.notify(.error, enabled: self.settings.hapticsEnabled)
                }
            }
            .store(in: &cancellables)
    }

    private func startStatsTimer() {
        statsTimer?.invalidate()
        statsTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if self.connection.state == .connected {
                    if let stats = await self.vpnManager.fetchStats() {
                        self.connection.stats = stats
                        AppGroup.defaults.encoded(self.connection, for: .connectionInfo)
                    }
                    self.objectWillChange.send()
                }
            }
        }
    }
}
