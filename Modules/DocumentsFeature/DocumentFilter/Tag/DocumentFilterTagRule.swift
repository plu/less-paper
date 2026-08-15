import Foundation

public enum DocumentFilterTagRule: String, CaseIterable, Equatable, Sendable {
    case all
    case any
    case assigned
    case notAssigned

    var isTagged: Bool? {
        switch self {
        case .all, .any:
            nil
        case .assigned:
            true
        case .notAssigned:
            false
        }
    }

    var localized: LocalizedStringResource {
        switch self {
        case .all:
            .all
        case .any:
            .any
        case .assigned:
            .assigned
        case .notAssigned:
            .notAssigned
        }
    }
}
