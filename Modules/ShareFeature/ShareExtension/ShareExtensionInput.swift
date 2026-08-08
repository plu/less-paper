import ComposableArchitecture
import Foundation

public enum ShareExtensionInput: Equatable {
    case extensionContext(NSExtensionContext?)
    case files([URL])

    func dismiss() -> Bool {
        switch self {
        case let .extensionContext(extensionContext):
            if let extensionContext {
                extensionContext.completeRequest(returningItems: nil)
                return true
            }
            return false
        case .files:
            return false
        }
    }
}
