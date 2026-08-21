import Foundation

enum DocumentFormSection: CaseIterable {
    case details
    case content
}

extension DocumentFormSection: CustomStringConvertible {

    var description: String {
        switch self {
        case .details:
            String(localized: .details)
        case .content:
            String(localized: .content)
        }
    }
}
