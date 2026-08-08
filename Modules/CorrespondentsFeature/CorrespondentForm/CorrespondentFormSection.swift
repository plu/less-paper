import Foundation

enum CorrespondentFormSection: CaseIterable {
    case form
    case permissions
}

extension CorrespondentFormSection: CustomStringConvertible {

    var description: String {
        switch self {
        case .form:
            String(localized: .correspondent)
        case .permissions:
            String(localized: .permissions)
        }
    }
}
