import Foundation

public enum DocumentFilterTagRule: String, CaseIterable, Equatable, Sendable {
    case all
    case any
    case notAssigned

    var localized: LocalizedStringResource {
        switch self {
        case .all:
            .all
        case .any:
            .any
        case .notAssigned:
            .notAssigned
        }
    }
}
