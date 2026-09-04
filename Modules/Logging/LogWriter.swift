import Foundation
import OSLog

// Owns the log file.
//
// An actor because writes arrive from every feature and from the networking layer at once.
// Serialising through the actor is what makes that safe without a lock, and it is also where
// trimming lives, so no caller has to know the file has a line cap.
public actor LogWriter {

    public static let shared = LogWriter()

    public func record(_ message: String, level: LogLevel, category: LogCategory, date: Date = Date()) {
        Logger(subsystem: subsystem, category: category.rawValue)
            .log(level: level.osLogType, "\(message, privacy: .public)")

        let line = "\(Self.formatter.string(from: date))  \(level.rawValue.padding(toLength: 5, withPad: " ", startingAt: 0))  \(category.rawValue.padding(toLength: 10, withPad: " ", startingAt: 0))  \(message)\n"
        append(line)
    }

    public func entries() -> [LogEntry] {
        contents(of: currentURL)
            .compactMap(Self.parse)
            .sorted { $0.date > $1.date }
    }

    public func fileURLs() -> [URL] {
        [currentURL].filter { fileManager.fileExists(atPath: $0.path()) }
    }

    public func clear() {
        try? fileManager.removeItem(at: currentURL)
        lineCount = nil
    }

    public init(
        directory: URL? = nil,
        fileManager: FileManager = .default,
        maximumLines: Int = 10_000
    ) {
        self.fileManager = fileManager
        self.maximumLines = maximumLines
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

    private let maximumLines: Int

    // Counted once from disk on the first write of a process, then tracked in memory. Recounting
    // per write would mean reading the whole file to append one line.
    private var lineCount: Int?

    private var currentURL: URL { directory.appending(path: "error.log") }

    private func append(_ line: String) {
        guard let data = line.data(using: .utf8) else {
            return
        }

        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

        if let handle = try? FileHandle(forWritingTo: currentURL) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: data)
        } else {
            try? data.write(to: currentURL)
        }

        lineCount = (lineCount ?? contents(of: currentURL).count - 1) + 1
        trimIfNeeded()
    }

    // Above the cap plus a tenth, not at the cap: trimming on every write past 10,000 would mean
    // rewriting the whole file for each line. The overshoot is bounded and the cap still holds.
    private func trimIfNeeded() {
        guard let count = lineCount, count > maximumLines + maximumLines / 10 else {
            return
        }

        let kept = contents(of: currentURL).suffix(maximumLines)
        do {
            try kept.joined(separator: "\n").appending("\n").write(to: currentURL, atomically: true, encoding: .utf8)
            lineCount = kept.count
        } catch {
            // The file still holds the untrimmed content, so the count that describes it is gone.
            // Recounting on the next write costs one read and is what stops a failed trim from
            // disabling the cap for the rest of the process.
            lineCount = nil
        }
    }

    private func contents(of url: URL) -> [String] {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else {
            return []
        }
        return text.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
    }
}
