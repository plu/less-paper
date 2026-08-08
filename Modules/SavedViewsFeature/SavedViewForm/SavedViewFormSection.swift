import Foundation

enum SavedViewFormSection: CaseIterable {
    case form
    case permissions
}

extension SavedViewFormSection: CustomStringConvertible {

    var description: String {
        switch self {
        case .form:
            String(localized: .savedView)
        case .permissions:
            String(localized: .permissions)
        }
    }
}
