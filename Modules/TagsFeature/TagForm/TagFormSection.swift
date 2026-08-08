import Foundation

enum TagFormSection: CaseIterable {
    case form
    case permissions
}

extension TagFormSection: CustomStringConvertible {

    var description: String {
        switch self {
        case .form:
            String(localized: .tag)
        case .permissions:
            String(localized: .permissions)
        }
    }
}
