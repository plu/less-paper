import Components
import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
struct ForwardAuthConfirmationPresenter: Sendable {

    // Returns true if the user tapped "Sign in", false if they dismissed the popup.
    var present: @Sendable (_ host: String) async -> Bool = { _ in false }
}

extension ForwardAuthConfirmationPresenter: TestDependencyKey {

    static let previewValue = Self(
        present: { _ in true }
    )

    static let testValue = Self()
}

extension ForwardAuthConfirmationPresenter: DependencyKey {

    static let liveValue = Self(
        present: present(host:)
    )
}

private extension ForwardAuthConfirmationPresenter {

    static func present(host: String) async -> Bool {
        @Dependency(\.popupPresenter)
        var popupPresenter

        return await popupPresenter.present { resolve in
            ConfirmationPopupView(
                title: .forwardAuthPopupTitle,
                message: .forwardAuthPopupMessage(host),
                confirmTitle: .forwardAuthPopupSignIn,
                cancel: { resolve(false) },
                confirm: { resolve(true) }
            )
        } ?? false
    }
}

extension DependencyValues {

    var forwardAuthConfirmation: ForwardAuthConfirmationPresenter {
        get { self[ForwardAuthConfirmationPresenter.self] }
        set { self[ForwardAuthConfirmationPresenter.self] = newValue }
    }
}
