import Foundation

enum StoragePathFormSection: CaseIterable {
    case form
    case permissions
}

extension StoragePathFormSection: CustomStringConvertible {

    var description: String {
        switch self {
        case .form:
            String(localized: .storagePath)
        case .permissions:
            String(localized: .permissions)
        }
    }
}
