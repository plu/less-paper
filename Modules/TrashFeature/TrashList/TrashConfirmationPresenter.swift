import Components
import Dependencies
import DependenciesMacros
import Foundation

/// Asks before anything is destroyed, the same way every other delete here does.
@DependencyClient
struct TrashConfirmationPresenter: Sendable {

    var confirmDeleteForever: @Sendable (_ title: String) async -> Bool = { _ in false }

    var confirmEmptyTrash: @Sendable () async -> Bool = { false }
}

extension TrashConfirmationPresenter: TestDependencyKey {

    static let previewValue = Self(
        confirmDeleteForever: { _ in false },
        confirmEmptyTrash: { false }
    )

    static let testValue = Self()
}

extension TrashConfirmationPresenter: DependencyKey {

    static let liveValue = Self(
        confirmDeleteForever: { title in
            await present(
                title: .trashDeleteForever,
                message: .trashDeleteForeverMessage(title)
            )
        },
        confirmEmptyTrash: {
            await present(
                title: .trashEmptyAll,
                message: .trashEmptyAllMessage
            )
        }
    )
}

private extension TrashConfirmationPresenter {

    static func present(
        title: LocalizedStringResource,
        message: LocalizedStringResource
    ) async -> Bool {
        @Dependency(\.popupPresenter)
        var popupPresenter

        return await popupPresenter.present { resolve in
            ConfirmationPopupView(
                title: title,
                message: message,
                isDestructive: true,
                cancel: { resolve(false) },
                confirm: { resolve(true) }
            )
        } ?? false
    }
}

extension DependencyValues {

    var trashConfirmation: TrashConfirmationPresenter {
        get { self[TrashConfirmationPresenter.self] }
        set { self[TrashConfirmationPresenter.self] = newValue }
    }
}
