import Foundation
import OSLog

public enum LogLevel: String, CaseIterable, Sendable, Comparable {
    case info = "INFO"
    case warning = "WARN"
    case error = "ERROR"

    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.order < rhs.order
    }

    var osLogType: OSLogType {
        switch self {
        case .info: .info
        case .warning: .default
        case .error: .error
        }
    }

    private var order: Int {
        switch self {
        case .info: 0
        case .warning: 1
        case .error: 2
        }
    }
}
