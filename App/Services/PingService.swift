import Foundation
import Darwin
import Network

public struct PingResult: Codable, Equatable, Sendable {
    public var latencyMs: Int?
    public var error: String?
    public var measuredAt: Date

    public var isSuccess: Bool { latencyMs != nil }

    public static let probeURL = URL(string: "https://www.gstatic.com/generate_204")!
}

public actor PingService {

    public init() {}

    public func ping(server: Server, protocol p: PingProtocol) async -> PingResult {
        switch p {
        case .tcp:      return await tcpPing(host: server.address, port: server.port)
        case .httpGet:  return await httpPing(method: "GET",  url: PingResult.probeURL)
        case .httpHead: return await httpPing(method: "HEAD", url: PingResult.probeURL)
        case .icmp:     return await icmpPing(host: server.address)
        }
    }

    // MARK: – TCP

    private func tcpPing(host: String, port: Int, timeout: TimeInterval = 4) async -> PingResult {
        await withCheckedContinuation { continuation in
            let started = Date()
            let conn = NWConnection(
                host: NWEndpoint.Host(host),
                port: NWEndpoint.Port(integerLiteral: UInt16(port)),
                using: .tcp
            )

            let resumeOnce = OnceResumer(continuation: continuation)
            let queue = DispatchQueue(label: "ping.tcp.\(host).\(port)")

            conn.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    let ms = Int(Date().timeIntervalSince(started) * 1000)
                    conn.cancel()
                    resumeOnce.resume(.init(latencyMs: ms, error: nil, measuredAt: Date()))
                case .failed(let err):
                    conn.cancel()
                    resumeOnce.resume(.init(latencyMs: nil, error: err.localizedDescription, measuredAt: Date()))
                case .cancelled:
                    resumeOnce.resume(.init(latencyMs: nil, error: "cancelled", measuredAt: Date()))
                default: break
                }
            }
            conn.start(queue: queue)

            queue.asyncAfter(deadline: .now() + timeout) {
                conn.cancel()
                resumeOnce.resume(.init(latencyMs: nil, error: "timeout", measuredAt: Date()))
            }
        }
    }

    // MARK: – HTTP

    private func httpPing(method: String, url: URL, timeout: TimeInterval = 6) async -> PingResult {
        var req = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: timeout)
        req.httpMethod = method
        req.setValue("Mozilla/5.0 (iPhone) VPNClient", forHTTPHeaderField: "User-Agent")

        let started = Date()
        do {
            let (_, response) = try await URLSession.shared.data(for: req)
            let ms = Int(Date().timeIntervalSince(started) * 1000)
            if let http = response as? HTTPURLResponse, (200..<400).contains(http.statusCode) {
                return .init(latencyMs: ms, error: nil, measuredAt: Date())
            }
            return .init(latencyMs: ms, error: "HTTP error", measuredAt: Date())
        } catch {
            return .init(latencyMs: nil, error: error.localizedDescription, measuredAt: Date())
        }
    }

    // MARK: – ICMP (best effort via SimplePing-style raw socket)

    private func icmpPing(host: String, timeout: TimeInterval = 4) async -> PingResult {
        // True ICMP requires a raw socket — Apple's `SimplePing` sample uses
        // SOCK_DGRAM with IPPROTO_ICMP which works on iOS without entitlement.
        // We fall back to an HTTP probe on failure.
        let pinger = ICMPPinger(host: host, timeout: timeout)
        if let ms = await pinger.ping() {
            return .init(latencyMs: ms, error: nil, measuredAt: Date())
        }
        return await httpPing(method: "HEAD", url: PingResult.probeURL, timeout: timeout)
    }
}

private final class OnceResumer {
    private var resumed = false
    private let lock = NSLock()
    let continuation: CheckedContinuation<PingResult, Never>

    init(continuation: CheckedContinuation<PingResult, Never>) {
        self.continuation = continuation
    }

    func resume(_ value: PingResult) {
        lock.lock()
        defer { lock.unlock() }
        guard !resumed else { return }
        resumed = true
        continuation.resume(returning: value)
    }
}

// MARK: – ICMP socket helper

import Darwin

/// Minimal SOCK_DGRAM-based ICMP echo. On iOS this does NOT require a special
/// entitlement and is what Apple's SimplePing sample is based on.
final class ICMPPinger {
    private let host: String
    private let timeout: TimeInterval
    private var socketFD: Int32 = -1

    init(host: String, timeout: TimeInterval) {
        self.host = host
        self.timeout = timeout
    }

    deinit {
        if socketFD >= 0 { close(socketFD) }
    }

    func ping() async -> Int? {
        await withCheckedContinuation { (continuation: CheckedContinuation<Int?, Never>) in
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self else {
                    continuation.resume(returning: nil); return
                }
                continuation.resume(returning: self.runBlocking())
            }
        }
    }

    private func runBlocking() -> Int? {
        socketFD = socket(AF_INET, SOCK_DGRAM, IPPROTO_ICMP)
        guard socketFD >= 0 else { return nil }

        var tv = timeval(tv_sec: Int(timeout), tv_usec: 0)
        setsockopt(socketFD, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))

        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = 0
        guard inet_pton(AF_INET, host, &addr.sin_addr) == 1 else { return nil }

        var packet = [UInt8](repeating: 0, count: 64)
        packet[0] = 0x08 // ICMP echo request
        packet[1] = 0x00
        let identifier = UInt16.random(in: 0...UInt16.max)
        packet[4] = UInt8(identifier >> 8)
        packet[5] = UInt8(identifier & 0xff)
        packet[6] = 0
        packet[7] = 0
        // checksum
        var sum: UInt32 = 0
        for i in stride(from: 0, to: 64, by: 2) {
            let word = (UInt16(packet[i]) << 8) | UInt16(packet[i + 1])
            sum &+= UInt32(word)
        }
        sum = (sum >> 16) &+ (sum & 0xffff)
        sum = sum &+ (sum >> 16)
        let checksum = ~UInt16(sum & 0xffff)
        packet[2] = UInt8(checksum >> 8)
        packet[3] = UInt8(checksum & 0xff)

        let started = Date()
        let sent = packet.withUnsafeBytes { ptr -> ssize_t in
            withUnsafePointer(to: &addr) { addrPtr in
                addrPtr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                    sendto(socketFD, ptr.baseAddress, packet.count, 0, sa, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
        }
        guard sent == packet.count else { return nil }

        var buf = [UInt8](repeating: 0, count: 1500)
        let bufLen = buf.count
        let received = buf.withUnsafeMutableBytes { ptr -> ssize_t in
            recv(socketFD, ptr.baseAddress, bufLen, 0)
        }
        guard received > 0 else { return nil }
        return Int(Date().timeIntervalSince(started) * 1000)
    }
}
