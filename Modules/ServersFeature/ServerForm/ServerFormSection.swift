import Foundation

enum ServerFormSection: CaseIterable {
    case form
    case advanced
}

extension ServerFormSection: CustomStringConvertible {

    var description: String {
        switch self {
        case .form:
            String(localized: .server)
        case .advanced:
            String(localized: .advanced)
        }
    }
}
