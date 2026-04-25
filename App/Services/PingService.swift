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

    // MARK: – TCP (real handshake RTT via POSIX socket)

    private func tcpPing(host: String, port: Int, timeout: TimeInterval = 4) async -> PingResult {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let result = Self.posixTcpPing(host: host, port: port, timeout: timeout)
                continuation.resume(returning: result)
            }
        }
    }

    /// Resolves the host, then non-blocking connect()+poll() to measure the real
    /// SYN→SYN-ACK round-trip. NWConnection's `.ready` state can fire well
    /// before the kernel actually completes the handshake on cellular, which
    /// produces unrealistic 0–1 ms readings — so we go to BSD sockets.
    private static func posixTcpPing(host: String, port: Int, timeout: TimeInterval) -> PingResult {
        var hints = addrinfo()
        hints.ai_family = AF_UNSPEC
        hints.ai_socktype = SOCK_STREAM
        hints.ai_protocol = IPPROTO_TCP

        var res: UnsafeMutablePointer<addrinfo>? = nil
        let status = getaddrinfo(host, String(port), &hints, &res)
        guard status == 0, let info = res else {
            return PingResult(latencyMs: nil, error: "DNS \(host) failed", measuredAt: Date())
        }
        defer { freeaddrinfo(info) }

        let fd = socket(info.pointee.ai_family,
                        info.pointee.ai_socktype,
                        info.pointee.ai_protocol)
        guard fd >= 0 else {
            return PingResult(latencyMs: nil, error: "socket() failed", measuredAt: Date())
        }
        defer { close(fd) }

        // Non-blocking
        let oldFlags = fcntl(fd, F_GETFL, 0)
        _ = fcntl(fd, F_SETFL, oldFlags | O_NONBLOCK)

        let started = Date()
        let connectResult = connect(fd, info.pointee.ai_addr, info.pointee.ai_addrlen)

        if connectResult == 0 {
            let ms = Int((Date().timeIntervalSince(started) * 1000).rounded())
            return PingResult(latencyMs: ms, error: nil, measuredAt: Date())
        }

        if errno != EINPROGRESS {
            let msg = String(cString: strerror(errno))
            return PingResult(latencyMs: nil, error: "connect: \(msg)", measuredAt: Date())
        }

        // Wait for writability (= handshake completion) or timeout.
        var pfd = pollfd(fd: fd, events: Int16(POLLOUT), revents: 0)
        let polled = poll(&pfd, 1, Int32(timeout * 1000))

        if polled == 0 {
            return PingResult(latencyMs: nil, error: "timeout", measuredAt: Date())
        }
        if polled < 0 {
            let msg = String(cString: strerror(errno))
            return PingResult(latencyMs: nil, error: "poll: \(msg)", measuredAt: Date())
        }

        // Inspect SO_ERROR: zero means the handshake actually succeeded.
        var soerr: Int32 = 0
        var len = socklen_t(MemoryLayout<Int32>.size)
        getsockopt(fd, SOL_SOCKET, SO_ERROR, &soerr, &len)
        if soerr != 0 {
            let msg = String(cString: strerror(soerr))
            return PingResult(latencyMs: nil, error: "tcp: \(msg)", measuredAt: Date())
        }

        let ms = Int((Date().timeIntervalSince(started) * 1000).rounded())
        // Anything claiming sub-millisecond on a remote host is a measurement
        // glitch; clamp to 1 so the UI doesn't show "0 мс".
        return PingResult(latencyMs: max(ms, 1), error: nil, measuredAt: Date())
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
