import Dependencies
import UIKit

public extension DependencyValues {
    var popupPresentationController: UIViewController? {
        get { self[Optional<UIViewController>.self] }
        set { self[Optional<UIViewController>.self] = newValue }
    }
}

extension Optional<UIViewController>: @retroactive DependencyKey, @retroactive TestDependencyKey {
    public static let liveValue = Optional.none
    public static let testValue = Optional.none
}
