import Components
import Dependencies
import DependenciesMacros
import Foundation

/// Asks before clearing, the same way deleting anything else here does.
@DependencyClient
struct ClearLogConfirmationPresenter: Sendable {
    var present: @Sendable () async -> Bool = { false }
}

extension ClearLogConfirmationPresenter: TestDependencyKey {

    static let previewValue = Self(present: { false })

    static let testValue = Self()
}

extension ClearLogConfirmationPresenter: DependencyKey {

    static let liveValue = Self(
        present: {
            @Dependency(\.popupPresenter)
            var popupPresenter

            return await popupPresenter.present { resolve in
                ConfirmationPopupView(
                    title: .diagnosticsClear,
                    message: .diagnosticsClearMessage,
                    isDestructive: true,
                    cancel: { resolve(false) },
                    confirm: { resolve(true) }
                )
            } ?? false
        }
    )
}

extension DependencyValues {

    var clearLogConfirmation: ClearLogConfirmationPresenter {
        get { self[ClearLogConfirmationPresenter.self] }
        set { self[ClearLogConfirmationPresenter.self] = newValue }
    }
}
