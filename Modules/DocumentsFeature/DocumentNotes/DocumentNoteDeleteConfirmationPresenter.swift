import Components
import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
struct DocumentNoteDeleteConfirmationPresenter: Sendable {
    var present: @Sendable () async -> Bool = { false }
}

extension DocumentNoteDeleteConfirmationPresenter: TestDependencyKey {

    static let previewValue = Self(
        present: { false }
    )

    static let testValue = Self()
}

extension DocumentNoteDeleteConfirmationPresenter: DependencyKey {

    static let liveValue = Self(
        present: present
    )
}

private extension DocumentNoteDeleteConfirmationPresenter {

    static func present() async -> Bool {
        @Dependency(\.popupPresenter)
        var popupPresenter

        return await popupPresenter.present { resolve in
            ConfirmationPopupView(
                title: .deleteNote,
                message: .deleteNoteConfirmation,
                isDestructive: true,
                cancel: { resolve(false) },
                confirm: { resolve(true) }
            )
        } ?? false
    }
}

extension DependencyValues {

    var documentNoteDeleteConfirmation: DocumentNoteDeleteConfirmationPresenter {
        get { self[DocumentNoteDeleteConfirmationPresenter.self] }
        set { self[DocumentNoteDeleteConfirmationPresenter.self] = newValue }
    }
}
