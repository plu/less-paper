import Dependencies
import DependenciesMacros
import Foundation
import SwiftMessages
import SwiftUI
import UIKit

@DependencyClient
public struct PopupPresenter: Sendable {
    public var dismiss: @Sendable (
    ) async -> Void

    public var present: @Sendable (
        _ popup: @escaping @Sendable @MainActor () -> any View
    ) async -> Void
}

extension PopupPresenter: TestDependencyKey {
    public static let previewValue = Self()
    public static let testValue = Self()
}

public extension DependencyValues {
    var popupPresenter: PopupPresenter {
        get { self[PopupPresenter.self] }
        set { self[PopupPresenter.self] = newValue }
    }
}

extension PopupPresenter: DependencyKey {
    public static let liveValue = Self(
        dismiss: dismiss,
        present: present(popup:)
    )
}

private extension PopupPresenter {
    @MainActor
    static func dismiss() {
        SwiftMessages.hide()
    }

    @MainActor
    static func present(
        popup: @escaping () -> any View
    ) async {
        @Dependency(\.popupPresentationController)
        var popupPresentationController

        let view = MessageHostingView(
            id: UUID().uuidString,
            content: AnyView(popup())
        )

        var config = SwiftMessages.Config()
        config.dimMode = .gray(interactive: false)
        config.duration = .forever
        config.interactiveHide = false
        config.presentationContext = .window(windowLevel: .statusBar)
        if let popupPresentationController {
            config.presentationContext = .viewController(popupPresentationController)
        }
        config.presentationStyle = .center
        SwiftMessages.show(
            config: config,
            view: view
        )
    }
}
