import Foundation
import os.log

#if canImport(LibXray)
import LibXray
#endif

/// Bridges the PacketTunnelProvider to the libXray Go bindings.
///
/// The xcframework is embedded at build time (CI downloads it from
/// `wanliyunyan/LibXray` releases — see `.github/workflows/ios.yml` and
/// `project.yml`). At call time we hand JSON config to LibXray which boots
/// an in-process Xray-core instance with our VLESS+Reality outbound.
final class XrayController {

    private let log = OSLog(subsystem: "com.tt2819ais.vpnclient.tunnel", category: "xray")
    private var lastRxBytes: UInt64 = 0
    private var lastTxBytes: UInt64 = 0
    private var lastSampleAt: Date = .distantPast
    private var running: Bool = false

    /// `true` when the LibXray module is linked. Always true in shipped
    /// builds — left as a property so callers can keep the existing
    /// `guard xray.isAvailable` style check.
    var isAvailable: Bool {
        #if canImport(LibXray)
        return true
        #else
        return false
        #endif
    }

    /// Starts an xray-core instance with the given JSON configuration.
    /// `dataDir` is used by xray for geo-data and runtime files.
    func start(configJSON: String, dataDir: URL) throws {
        #if canImport(LibXray)
        try FileManager.default.createDirectory(at: dataDir, withIntermediateDirectories: true)
        let configPath = dataDir.appendingPathComponent("config.json")
        try configJSON.write(to: configPath, atomically: true, encoding: .utf8)

        os_log("Starting xray-core with config at %{public}@", log: log, type: .info, configPath.path)
        LogStore.shared.info("xray-core booting (config=\(configPath.lastPathComponent))", tag: "Tunnel")

        // libXray's RunXrayFromJSON wants a base64-encoded request envelope:
        //   { "datDir": "...", "configJSON": "...stringified..." }
        // The helper LibXrayNewXrayRunFromJSONRequest does that for us.
        var nsErr: NSError?
        let envelope = LibXrayNewXrayRunFromJSONRequest(dataDir.path, configJSON, &nsErr)
        if let nsErr {
            LogStore.shared.error("LibXray request build failed: \(nsErr.localizedDescription)", tag: "Tunnel")
            throw nsErr
        }
        let resp = LibXrayRunXrayFromJSON(envelope)
        try Self.throwIfNotSuccess(resp, op: "RunXrayFromJSON")
        running = true

        let version = LibXrayXrayVersion()
        LogStore.shared.info("xray-core started (version=\(version))", tag: "Tunnel")
        #else
        LogStore.shared.error("LibXray module not available — extension was built without the xcframework", tag: "Tunnel")
        throw NSError(domain: "XrayController", code: 100,
                      userInfo: [NSLocalizedDescriptionKey: "LibXray не слинкован в эту сборку extension'а"])
        #endif
    }

    func stop() {
        #if canImport(LibXray)
        guard running else { return }
        let resp = LibXrayStopXray()
        running = false
        if let parsed = Self.parseResponse(resp), parsed.success == false {
            LogStore.shared.error("xray-core stop reported failure: \(parsed.error ?? "?")", tag: "Tunnel")
        } else {
            LogStore.shared.info("xray-core stopped", tag: "Tunnel")
        }
        #endif
    }

    func queryStats() -> TrafficStats {
        #if canImport(LibXray)
        // Build the base64 envelope: { "server": "127.0.0.1:49227", ... }.
        // LibXray expects metrics endpoint to be running; if not it returns
        // an error response which we treat as zero stats (typical when the
        // user disabled metrics in their config).
        guard let envelope = makeQueryEnvelope() else { return .zero }
        let resp = LibXrayQueryStats(envelope)
        guard let parsed = Self.parseResponse(resp), parsed.success == true,
              let dataB64 = parsed.dataBase64,
              let dataBytes = Data(base64Encoded: dataB64),
              let json = try? JSONSerialization.jsonObject(with: dataBytes) as? [String: Any]
        else { return .zero }

        let rx = (json["downlink"] as? UInt64) ?? UInt64((json["downlink"] as? Int) ?? 0)
        let tx = (json["uplink"]   as? UInt64) ?? UInt64((json["uplink"]   as? Int) ?? 0)
        let now = Date()
        let dt = max(now.timeIntervalSince(lastSampleAt), 0.001)
        let rxRate = lastSampleAt == .distantPast ? 0 : UInt64(Double(rx &- lastRxBytes) / dt)
        let txRate = lastSampleAt == .distantPast ? 0 : UInt64(Double(tx &- lastTxBytes) / dt)
        lastRxBytes = rx
        lastTxBytes = tx
        lastSampleAt = now
        return TrafficStats(rxBytes: rx, txBytes: tx, rxRateBps: rxRate, txRateBps: txRate)
        #else
        return .zero
        #endif
    }

    // MARK: – LibXray response helpers

    private struct LibXrayResponse {
        let success: Bool?
        let error: String?
        let dataBase64: String?
    }

    private static func parseResponse(_ raw: String) -> LibXrayResponse? {
        guard let data = raw.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        return LibXrayResponse(
            success: dict["success"] as? Bool,
            error: dict["error"] as? String,
            dataBase64: dict["data"] as? String
        )
    }

    private static func throwIfNotSuccess(_ raw: String, op: String) throws {
        guard let parsed = parseResponse(raw) else {
            throw NSError(domain: "XrayController", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Не удалось разобрать ответ LibXray (\(op)): \(raw.prefix(180))"])
        }
        if parsed.success == false {
            let msg = parsed.error ?? "(no error message)"
            LogStore.shared.error("\(op) failed: \(msg)", tag: "Tunnel")
            throw NSError(domain: "XrayController", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "xray-core: \(msg)"])
        }
    }

    private func makeQueryEnvelope() -> String? {
        let payload: [String: Any] = ["server": "127.0.0.1:49227", "reset": false]
        guard let data = try? JSONSerialization.data(withJSONObject: payload) else { return nil }
        return data.base64EncodedString()
    }
}
