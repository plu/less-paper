import Components
import Dependencies
import DependenciesMacros
import Foundation

// Not DeleteConfirmationPresenter: this dismisses (acknowledges) rather than deletes, and that
// presenter hardcodes both the deletion message and isDestructive: true. Built directly on
// popupPresenter instead, the same primitive DeleteConfirmationPresenter itself is built on.
@DependencyClient
struct FileTaskDismissAllConfirmationPresenter: Sendable {

    var present: @Sendable (_ count: Int) async -> Bool = { _ in false }
}

extension FileTaskDismissAllConfirmationPresenter: TestDependencyKey {

    static let previewValue = Self(present: { _ in false })

    static let testValue = Self()
}

extension FileTaskDismissAllConfirmationPresenter: DependencyKey {

    static let liveValue = Self(
        present: present(count:)
    )
}

private extension FileTaskDismissAllConfirmationPresenter {

    static func present(count: Int) async -> Bool {
        @Dependency(\.popupPresenter)
        var popupPresenter

        return await popupPresenter.present { resolve in
            ConfirmationPopupView(
                title: .fileTasksDismissAllConfirmTitle,
                message: .fileTasksDismissAllConfirmMessage(count),
                isDestructive: false,
                cancel: { resolve(false) },
                confirm: { resolve(true) }
            )
        } ?? false
    }
}

extension DependencyValues {

    var fileTaskDismissAllConfirmation: FileTaskDismissAllConfirmationPresenter {
        get { self[FileTaskDismissAllConfirmationPresenter.self] }
        set { self[FileTaskDismissAllConfirmationPresenter.self] = newValue }
    }
}
