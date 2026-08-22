import Foundation

enum DocumentFormSection: CaseIterable {
    case content
    case details
    case notes
}

extension DocumentFormSection: CustomStringConvertible {

    var description: String {
        switch self {
        case .content:
            String(localized: .content)
        case .details:
            String(localized: .details)
        case .notes:
            String(localized: .notes)
        }
    }
}
