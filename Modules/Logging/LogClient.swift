import Dependencies
import DependenciesMacros
import Foundation

/// What features call.
///
/// Recording is non-throwing and fire-and-forget. A logger a caller must `await`, or that can fail,
/// is one people stop calling from the paths that matter most - which are exactly the paths where
/// something has already gone wrong.
@DependencyClient
public struct LogClient: Sendable {

    public var record: @Sendable (
        _ message: String,
        _ level: LogLevel,
        _ category: LogCategory
    ) -> Void

    public var entries: @Sendable () async -> [LogEntry] = { [] }

    public var fileURLs: @Sendable () async -> [URL] = { [] }

    public var clear: @Sendable () async -> Void

    public func error(_ message: String, category: LogCategory) {
        record(message, .error, category)
    }

    public func warning(_ message: String, category: LogCategory) {
        record(message, .warning, category)
    }

    public func info(_ message: String, category: LogCategory) {
        record(message, .info, category)
    }

    /// `localizedDescription` on its own is often "The operation couldn't be completed", so the
    /// underlying error is included where one exists.
    public func error(_ error: any Error, category: LogCategory) {
        let localized = error.localizedDescription
        let described = String(describing: error)
        record(described == localized ? localized : "\(localized) (\(described))", .error, category)
    }
}

extension LogClient: TestDependencyKey {

    public static let previewValue = Self(
        record: { _, _, _ in },
        entries: { [] },
        fileURLs: { [] },
        clear: {}
    )

    /// A no-op rather than unimplemented, matching the other clients here. Logging is incidental to
    /// what any given test is asserting, and an unimplemented default would make every test that
    /// happens to make a request fail for a reason that has nothing to do with it. A test that
    /// cares about logging overrides this and records the calls.
    public static let testValue = Self(
        record: { _, _, _ in },
        entries: { [] },
        fileURLs: { [] },
        clear: {}
    )
}

public extension DependencyValues {

    var log: LogClient {
        get { self[LogClient.self] }
        set { self[LogClient.self] = newValue }
    }
}
