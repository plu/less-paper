import Dependencies
import DependenciesMacros
import Foundation
import SwiftMessages
import SwiftUI

@DependencyClient
public struct ToastPresenter: Sendable {
    public var present: @Sendable (
        _ toast: Toast
    ) async -> Void
}

extension ToastPresenter: TestDependencyKey {
    public static let previewValue = Self()
    public static let testValue = Self()
}

public extension DependencyValues {
    var toastPresenter: ToastPresenter {
        get { self[ToastPresenter.self] }
        set { self[ToastPresenter.self] = newValue }
    }
}

extension ToastPresenter: DependencyKey {
    public static let liveValue = Self(
        present: present(toast:)
    )
}

private extension ToastPresenter {
    static func present(
        toast: Toast
    ) async {
        let view = await MessageHostingView(
            id: UUID().uuidString,
            content: ToastView(toast: toast)
        )
        var config = SwiftMessages.Config()
        switch toast {
        case .error:
            config.haptic = .error
        case .success:
            config.haptic = .success
        }
        config.presentationContext = .window(windowLevel: .statusBar)
        config.presentationStyle = .top
        await SwiftMessages.show(
            config: config,
            view: view
        )
    }
}
