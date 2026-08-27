import Foundation

/// One line, parsed back out of the log file for the Diagnostics screen.
public struct LogEntry: Equatable, Identifiable, Sendable {
    public let id: UUID
    public let date: Date
    public let level: LogLevel
    public let category: LogCategory
    public let message: String

    public init(id: UUID = UUID(), date: Date, level: LogLevel, category: LogCategory, message: String) {
        self.id = id
        self.date = date
        self.level = level
        self.category = category
        self.message = message
    }
}
