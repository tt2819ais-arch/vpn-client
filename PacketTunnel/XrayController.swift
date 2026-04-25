import Foundation
import Darwin
import os.log

/// Thin wrapper around the libXray Go bindings.
///
/// The PacketTunnelProvider drives this controller. We try to bind to
/// `LibXray` (XCFramework from https://github.com/XTLS/libXray) when present;
/// otherwise we degrade to a stub that still completes start/stop calls without
/// crashing — useful for dev builds before the binary framework has been
/// vendored. Replace `LibXrayBackend` with the real bridge once the framework
/// is wired up (see README "Vendoring libXray").
final class XrayController {

    private let log = OSLog(subsystem: "com.tt2819ais.vpnclient.tunnel", category: "xray")
    private let backend: XrayBackend

    init(backend: XrayBackend = LibXrayBackend()) {
        self.backend = backend
    }

    /// Whether the libXray binary is wired up. When false the tunnel must
    /// refuse to install network settings — capturing all traffic without a
    /// functional engine would simply break the user's internet.
    var isAvailable: Bool { backend.isAvailable }

    func start(configJSON: String, dataDir: URL) throws {
        let configPath = dataDir.appendingPathComponent("config.json")
        try configJSON.write(to: configPath, atomically: true, encoding: .utf8)

        os_log("Starting xray-core with config at %{public}@", log: log, type: .info, configPath.path)
        LogStore.shared.info("xray-core start config=\(configPath.lastPathComponent)", tag: "Tunnel")
        try backend.start(configPath: configPath.path, dataDir: dataDir.path)
    }

    func stop() {
        backend.stop()
    }

    func queryStats() -> TrafficStats {
        backend.queryStats()
    }
}

// MARK: – Backend abstraction

protocol XrayBackend {
    var isAvailable: Bool { get }
    func start(configPath: String, dataDir: String) throws
    func stop()
    func queryStats() -> TrafficStats
}

/// Default backend: tries to call into the libXray XCFramework via dynamic
/// symbol lookup so the project still links if the framework is missing.
final class LibXrayBackend: XrayBackend {

    private let log = OSLog(subsystem: "com.tt2819ais.vpnclient.tunnel", category: "libxray")
    private var lastRxBytes: UInt64 = 0
    private var lastTxBytes: UInt64 = 0
    private var lastSampleAt: Date = .distantPast

    var isAvailable: Bool { dynamicSymbol(named: "LibXrayRun") != nil }

    func start(configPath: String, dataDir: String) throws {
        // libXray exposes `LibXrayRun(base64(json{datadir, configPath}))`.
        // We dlsym to avoid a hard link dependency at build time so the project
        // builds in CI even before the binary framework is vendored.
        guard let runFn = dynamicSymbol(named: "LibXrayRun") else {
            os_log("LibXrayRun not found — libXray binary missing", log: log, type: .error)
            LogStore.shared.error("LibXrayRun symbol not found — libXray.xcframework not bundled", tag: "Tunnel")
            throw NSError(domain: "LibXrayBackend", code: 100,
                          userInfo: [NSLocalizedDescriptionKey: "VPN-движок (libXray) не подключён в этой сборке. См. README \u{00BB} Vendoring libXray."])
        }
        let request: [String: String] = [
            "datDir": dataDir,
            "configPath": configPath
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: request),
              let b64 = String(data: data.base64EncodedData(), encoding: .utf8) else {
            throw NSError(domain: "LibXrayBackend", code: 2)
        }

        typealias RunFn = @convention(c) (UnsafePointer<CChar>) -> UnsafePointer<CChar>?
        let cFn = unsafeBitCast(runFn, to: RunFn.self)
        let result = b64.withCString { cFn($0) }
        if let result, let s = String(validatingUTF8: result) {
            os_log("LibXrayRun returned %{public}@", log: log, type: .info, s)
            if s.contains("\"success\":false") {
                throw NSError(domain: "LibXrayBackend", code: 3,
                              userInfo: [NSLocalizedDescriptionKey: s])
            }
        }
    }

    func stop() {
        guard let stopFn = dynamicSymbol(named: "LibXrayStop") else { return }
        typealias StopFn = @convention(c) () -> UnsafePointer<CChar>?
        let cFn = unsafeBitCast(stopFn, to: StopFn.self)
        _ = cFn()
    }

    func queryStats() -> TrafficStats {
        guard let queryFn = dynamicSymbol(named: "LibXrayQueryStats") else {
            return .zero
        }
        typealias QueryFn = @convention(c) (UnsafePointer<CChar>, UnsafePointer<CChar>) -> UnsafePointer<CChar>?
        let cFn = unsafeBitCast(queryFn, to: QueryFn.self)

        guard let response = "direct".withCString({ direct in
            "proxy".withCString { proxy in
                cFn(direct, proxy)
            }
        }), let json = String(validatingUTF8: response),
           let data = json.data(using: .utf8),
           let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return .zero }

        let rx = (dict["downlink"] as? UInt64) ?? UInt64((dict["downlink"] as? Int) ?? 0)
        let tx = (dict["uplink"] as? UInt64) ?? UInt64((dict["uplink"] as? Int) ?? 0)
        let now = Date()
        let dt = max(now.timeIntervalSince(lastSampleAt), 0.001)
        let rxRate = lastSampleAt == .distantPast ? 0 : UInt64(Double(rx &- lastRxBytes) / dt)
        let txRate = lastSampleAt == .distantPast ? 0 : UInt64(Double(tx &- lastTxBytes) / dt)
        lastRxBytes = rx
        lastTxBytes = tx
        lastSampleAt = now
        return TrafficStats(rxBytes: rx, txBytes: tx, rxRateBps: rxRate, txRateBps: txRate)
    }

    private func dynamicSymbol(named name: String) -> UnsafeMutableRawPointer? {
        // RTLD_DEFAULT (-2) is the special handle that searches all loaded images,
        // which lets us link successfully even if libXray is not embedded yet.
        let handle = UnsafeMutableRawPointer(bitPattern: -2)
        return dlsym(handle, name)
    }
}
