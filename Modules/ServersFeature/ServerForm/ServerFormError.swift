import Foundation

enum ServerFormError: Error, Equatable {
    case credentialsRequired
}

extension ServerFormError: LocalizedError {

    var errorDescription: String? {
        switch self {
        case .credentialsRequired:
            String(localized: .serverFormCredentialsRequired)
        }
    }
}
