import Dependencies
import Foundation
import Logging

/// The API decoder, with a note taken when decoding fails.
///
/// Decoding happens after `validateResponse`, inside `Get`, so a malformed body throws somewhere the
/// delegate never sees. Without this a 200 carrying JSON the app cannot read produced no log line at
/// all - which is the one failure a user is least able to describe and most needs recorded.
///
/// The path is carried because the error alone does not say which endpoint returned the body, and
/// "expected String, found Int" is not actionable without knowing where.
final class LoggingJSONDecoder: JSONDecoder, @unchecked Sendable {

    init(path: String) {
        self.path = path
        super.init()
    }

    override func decode<T>(_ type: T.Type, from data: Data) throws -> T where T: Decodable {
        do {
            return try super.decode(type, from: data)
        } catch {
            @Dependency(\.log)
            var log

            // The type and the reason, never the body: a paperless response is the user's paperwork.
            log.error("decoding \(type) from \(path) failed: \(description(of: error))", category: .api)
            throw error
        }
    }

    private let path: String

    /// `DecodingError`'s `localizedDescription` is "The data couldn’t be read because it isn’t in the
    /// correct format", which is true of every one of them and useful for none.
    private func description(of error: any Error) -> String {
        guard let error = error as? DecodingError else {
            return String(describing: error)
        }

        return switch error {
        case let .dataCorrupted(context):
            "data corrupted at \(path(of: context)): \(context.debugDescription)"
        case let .keyNotFound(key, context):
            "missing key '\(key.stringValue)' at \(path(of: context))"
        case let .typeMismatch(type, context):
            "expected \(type) at \(path(of: context))"
        case let .valueNotFound(type, context):
            "no value for \(type) at \(path(of: context))"
        @unknown default:
            String(describing: error)
        }
    }

    private func path(of context: DecodingError.Context) -> String {
        let keys = context.codingPath.map(\.stringValue)
        return keys.isEmpty ? "the root" : keys.joined(separator: ".")
    }
}
