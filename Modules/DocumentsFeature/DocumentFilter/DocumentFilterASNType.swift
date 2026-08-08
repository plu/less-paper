import Foundation

public enum DocumentFilterASNType: String, CaseIterable, Equatable, Identifiable, Sendable {
    case equals
    case isEmpty
    case isNotEmpty
    case greaterThan
    case lowerThan

    public var id: RawValue { rawValue }
}

extension DocumentFilterASNType {

    var localized: LocalizedStringResource {
        switch self {
        case .equals:
            .asnTypeEquals
        case .isEmpty:
            .asnTypeIsEmpty
        case .isNotEmpty:
            .asnTypeIsNotEmpty
        case .greaterThan:
            .asnTypeGreaterThan
        case .lowerThan:
            .asnTypeLowerThan
        }
    }
}
