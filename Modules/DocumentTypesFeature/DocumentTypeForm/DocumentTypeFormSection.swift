import Foundation

enum DocumentTypeFormSection: CaseIterable {
    case form
    case permissions
}

extension DocumentTypeFormSection: CustomStringConvertible {

    var description: String {
        switch self {
        case .form:
            String(localized: .documentType)
        case .permissions:
            String(localized: .permissions)
        }
    }
}
