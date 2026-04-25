import Foundation
import Combine

/// Persistent server list shared between the main app and extensions
/// via the App Group `UserDefaults` suite.
@MainActor
public final class ServerStore: ObservableObject {
    public static let shared = ServerStore()

    @Published public private(set) var servers: [Server]

    private let defaults = AppGroup.defaults

    public init() {
        if let stored = AppGroup.defaults.decoded([Server].self, for: .servers), !stored.isEmpty {
            self.servers = stored
        } else {
            self.servers = Server.bundled
            AppGroup.defaults.encoded(Server.bundled, for: .servers)
        }
    }

    public func add(_ server: Server) {
        servers.append(server)
        persist()
    }

    public func remove(_ server: Server) {
        servers.removeAll { $0.id == server.id }
        persist()
    }

    public func update(_ server: Server) {
        guard let idx = servers.firstIndex(where: { $0.id == server.id }) else { return }
        servers[idx] = server
        persist()
    }

    public func resetToBundled() {
        servers = Server.bundled
        persist()
    }

    public func server(with id: UUID) -> Server? {
        servers.first { $0.id == id }
    }

    private func persist() {
        defaults.encoded(servers, for: .servers)
    }
}
