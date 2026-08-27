import Foundation
import OSLog

/// Owns the log file.
///
/// An actor because writes arrive from every feature and from the networking layer at once.
/// Serialising through the actor is what makes that safe without a lock, and it is also where
/// rotation lives, so no caller has to know the file has a size limit.
public actor LogWriter {

    public static let shared = LogWriter()

    public func record(_ message: String, level: LogLevel, category: LogCategory, date: Date = Date()) {
        Logger(subsystem: subsystem, category: category.rawValue)
            .log(level: level.osLogType, "\(message, privacy: .public)")

        let line = "\(Self.formatter.string(from: date))  \(level.rawValue.padding(toLength: 5, withPad: " ", startingAt: 0))  \(category.rawValue.padding(toLength: 10, withPad: " ", startingAt: 0))  \(message)\n"
        append(line)
    }

    public func entries() -> [LogEntry] {
        // Newest first, and the rotated file after the current one, so a read is in one order.
        (contents(of: currentURL) + contents(of: rotatedURL))
            .compactMap(Self.parse)
            .sorted { $0.date > $1.date }
    }

    public func fileURLs() -> [URL] {
        [currentURL, rotatedURL].filter { fileManager.fileExists(atPath: $0.path()) }
    }

    public func clear() {
        for url in [currentURL, rotatedURL] {
            try? fileManager.removeItem(at: url)
        }
    }

    public init(
        directory: URL? = nil,
        fileManager: FileManager = .default,
        maximumSize: Int = 1_048_576
    ) {
        self.fileManager = fileManager
        self.maximumSize = maximumSize
        // Caches, as the old app used: the system may reclaim it under storage pressure, which is
        // the right trade for diagnostics. They must never be why a document cannot be saved.
        self.directory = directory ?? fileManager
            .urls(for: .cachesDirectory, in: .userDomainMask)
            .last!
            .appending(path: "log")
    }

    static func parse(_ line: String) -> LogEntry? {
        // Split on the double space the writer uses as a column separator, so a message containing
        // single spaces - which every message does - survives intact.
        let columns = line.components(separatedBy: "  ").filter { !$0.isEmpty }
        guard columns.count >= 4,
              let date = formatter.date(from: columns[0]),
              let level = LogLevel(rawValue: columns[1].trimmingCharacters(in: .whitespaces)),
              let category = LogCategory(rawValue: columns[2].trimmingCharacters(in: .whitespaces))
        else {
            return nil
        }

        return LogEntry(
            date: date,
            level: level,
            category: category,
            message: columns[3...].joined(separator: "  ").trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        // Fixed and sortable, and en_US_POSIX so a user's locale cannot change the file's shape.
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter
    }()

    private let subsystem = "com.aptumtek.app.Paperless"

    private let fileManager: FileManager

    private let directory: URL

    private let maximumSize: Int

    private var currentURL: URL { directory.appending(path: "error.log") }

    private var rotatedURL: URL { directory.appending(path: "error.1.log") }

    private func append(_ line: String) {
        guard let data = line.data(using: .utf8) else {
            return
        }

        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        rotateIfNeeded(adding: data.count)

        guard let handle = try? FileHandle(forWritingTo: currentURL) else {
            try? data.write(to: currentURL)
            return
        }
        defer { try? handle.close() }
        _ = try? handle.seekToEnd()
        try? handle.write(contentsOf: data)
    }

    /// Checked on write rather than on a timer, because a timer is a second thing that can be wrong.
    private func rotateIfNeeded(adding bytes: Int) {
        let attributes = try? fileManager.attributesOfItem(atPath: currentURL.path())
        let size = (attributes?[.size] as? Int) ?? 0
        guard size + bytes > maximumSize else {
            return
        }

        try? fileManager.removeItem(at: rotatedURL)
        try? fileManager.moveItem(at: currentURL, to: rotatedURL)
    }

    private func contents(of url: URL) -> [String] {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else {
            return []
        }
        return text.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
    }
}
