import Foundation

public enum DocumentFormSection: CaseIterable, Sendable {
    case content
    case customFields
    case details
    case notes
}

extension DocumentFormSection: CustomStringConvertible {

    public var description: String {
        switch self {
        case .content:
            String(localized: .content)
        case .customFields:
            String(localized: .customFields)
        case .details:
            String(localized: .details)
        case .notes:
            String(localized: .notes)
        }
    }
}
