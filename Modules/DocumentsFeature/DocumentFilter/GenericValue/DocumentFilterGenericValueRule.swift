import Foundation

public enum DocumentFilterGenericValueRule: String, CaseIterable, Equatable, Sendable {
    case include
    case exclude
    case notAssigned

    var localized: LocalizedStringResource {
        switch self {
        case .include:
            .include
        case .exclude:
            .exclude
        case .notAssigned:
            .notAssigned
        }
    }
}
