import Foundation

enum ShareFormError: Error, Equatable {
    case unlockFailed
}

extension ShareFormError: LocalizedError {

    var errorDescription: String? {
        switch self {
        case .unlockFailed:
            String(localized: .unlockFailed)
        }
    }
}
