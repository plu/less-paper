import Foundation

enum ShareFormError: Error, Equatable {
    case forwardAuthRequired
    case unlockFailed
}

extension ShareFormError: LocalizedError {

    var errorDescription: String? {
        switch self {
        case .forwardAuthRequired:
            String(localized: .shareFormForwardAuthRequired)
        case .unlockFailed:
            String(localized: .unlockFailed)
        }
    }
}
