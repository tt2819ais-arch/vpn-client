import Foundation

/// Shared logging service. Writes plain-text lines to a rotating log file in
/// the App Group container so that both the main app and the PacketTunnel
/// extension can append (and the UI can read them back).
public final class LogStore: @unchecked Sendable {

    public static let shared = LogStore()

    public enum Level: String, Codable, Sendable {
        case debug = "DEBUG"
        case info  = "INFO"
        case warn  = "WARN"
        case error = "ERROR"
    }

    public struct Entry: Codable, Identifiable, Sendable {
        public var id: UUID
        public var date: Date
        public var level: Level
        public var tag: String
        public var message: String

        public init(id: UUID = UUID(), date: Date = Date(), level: Level, tag: String, message: String) {
            self.id = id
            self.date = date
            self.level = level
            self.tag = tag
            self.message = message
        }

        public var formatted: String {
            let f = LogStore.dateFormatter
            return "\(f.string(from: date)) [\(level.rawValue.padding(toLength: 5, withPad: " ", startingAt: 0))] [\(tag)] \(message)"
        }
    }

    private let queue = DispatchQueue(label: "vpnclient.logstore", qos: .utility)
    private let fileURL: URL
    private let archiveURL: URL
    private let maxBytes: Int = 2 * 1024 * 1024 // 2 MB live, +archive of equal size

    fileprivate static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone.current
        f.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return f
    }()

    public init() {
        let dir = AppGroup.containerURL.appendingPathComponent("Logs", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.fileURL = dir.appendingPathComponent("app.log")
        self.archiveURL = dir.appendingPathComponent("app.prev.log")
        if !FileManager.default.fileExists(atPath: fileURL.path) {
            FileManager.default.createFile(atPath: fileURL.path, contents: nil)
        }
    }

    // MARK: – Writing

    public func log(_ message: String, level: Level = .info, tag: String = "App") {
        let entry = Entry(level: level, tag: tag, message: message)
        let line = entry.formatted + "\n"
        queue.async { [self] in
            self.append(line: line)
        }
    }

    /// Synchronous variant — guarantees the line is on disk before returning.
    /// Use from the PacketTunnel extension's boot path so we never lose
    /// breadcrumbs when iOS tears the extension down mid-launch.
    public func logSync(_ message: String, level: Level = .info, tag: String = "App") {
        let entry = Entry(level: level, tag: tag, message: message)
        let line = entry.formatted + "\n"
        queue.sync { [self] in
            self.append(line: line)
        }
    }

    public func debug(_ message: String, tag: String = "App") { log(message, level: .debug, tag: tag) }
    public func info(_ message: String,  tag: String = "App") { log(message, level: .info,  tag: tag) }
    public func warn(_ message: String,  tag: String = "App") { log(message, level: .warn,  tag: tag) }
    public func error(_ message: String, tag: String = "App") { log(message, level: .error, tag: tag) }

    private func append(line: String) {
        guard let data = line.data(using: .utf8) else { return }
        do {
            let handle: FileHandle
            if FileManager.default.fileExists(atPath: fileURL.path) {
                handle = try FileHandle(forWritingTo: fileURL)
                try handle.seekToEnd()
            } else {
                FileManager.default.createFile(atPath: fileURL.path, contents: nil)
                handle = try FileHandle(forWritingTo: fileURL)
            }
            try handle.write(contentsOf: data)
            try handle.close()

            try rotateIfNeeded()
        } catch {
            // best effort
        }
    }

    private func rotateIfNeeded() throws {
        let attrs = try FileManager.default.attributesOfItem(atPath: fileURL.path)
        let size = (attrs[.size] as? NSNumber)?.intValue ?? 0
        if size >= maxBytes {
            if FileManager.default.fileExists(atPath: archiveURL.path) {
                try? FileManager.default.removeItem(at: archiveURL)
            }
            try FileManager.default.moveItem(at: fileURL, to: archiveURL)
            FileManager.default.createFile(atPath: fileURL.path, contents: nil)
        }
    }

    // MARK: – Reading

    public func read(maxBytes limit: Int = 256 * 1024) -> String {
        queue.sync {
            var combined = ""
            if let archive = try? Data(contentsOf: archiveURL),
               let s = String(data: archive, encoding: .utf8) {
                combined.append(s)
            }
            if let live = try? Data(contentsOf: fileURL),
               let s = String(data: live, encoding: .utf8) {
                combined.append(s)
            }
            // Keep only the tail to bound memory.
            if combined.count > limit {
                let idx = combined.index(combined.endIndex, offsetBy: -limit)
                combined = String(combined[idx...])
                if let nl = combined.firstIndex(of: "\n") {
                    combined = String(combined[combined.index(after: nl)...])
                }
            }
            return combined
        }
    }

    public func clear() {
        queue.sync {
            try? FileManager.default.removeItem(at: archiveURL)
            try? FileManager.default.removeItem(at: fileURL)
            FileManager.default.createFile(atPath: fileURL.path, contents: nil)
        }
    }
}
