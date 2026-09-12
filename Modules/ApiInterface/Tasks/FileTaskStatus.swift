import Foundation

public enum FileTaskStatus: String, CaseIterable, Codable, Equatable, Sendable {
    case complete
    case failed
    case queued
    case started

    // v9 shouts its celery states (SUCCESS), v10 lower-cases them (success), and the rest of the app
    // should never have to know which server it is talking to.
    public init?(apiValue: String) {
        switch apiValue.lowercased() {
        case "success":
            self = .complete
        case "failure", "revoked":
            self = .failed
        case "started":
            self = .started
        case "pending":
            self = .queued
        default:
            return nil
        }
    }

    // Never throws. A status written by a future build of this app, or read from a cache it left
    // behind, must not fail the decode of everything around it.
    public init(from decoder: any Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = Self(rawValue: raw) ?? Self(apiValue: raw) ?? .queued
    }
}
