import Foundation

enum DocumentFormSection: CaseIterable {
    case details
    case content
    case notes
}

extension DocumentFormSection: CustomStringConvertible {

    var description: String {
        switch self {
        case .details:
            String(localized: .details)
        case .content:
            String(localized: .content)
        case .notes:
            String(localized: .notes)
        }
    }
}
