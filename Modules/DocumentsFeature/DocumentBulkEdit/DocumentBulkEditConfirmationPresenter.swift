import Components
import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
struct DocumentBulkEditConfirmationPresenter: Sendable {

    /// Presents the confirmation popup and suspends until the user confirms or cancels
    var present: @Sendable (_ message: LocalizedStringResource) async -> Bool = { _ in false }
}

extension DocumentBulkEditConfirmationPresenter: TestDependencyKey {

    static let previewValue = Self(present: { _ in false })

    static let testValue = Self()
}

extension DocumentBulkEditConfirmationPresenter: DependencyKey {

    static let liveValue = Self(
        present: present(message:)
    )
}

private extension DocumentBulkEditConfirmationPresenter {

    static func present(message: LocalizedStringResource) async -> Bool {
        @Dependency(\.popupPresenter)
        var popupPresenter

        return await popupPresenter.present { resolve in
            ConfirmationPopupView(
                title: .confirmAssignment,
                message: message,
                cancel: { resolve(false) },
                confirm: { resolve(true) }
            )
        } ?? false
    }
}

extension DependencyValues {

    var documentBulkEditConfirmation: DocumentBulkEditConfirmationPresenter {
        get { self[DocumentBulkEditConfirmationPresenter.self] }
        set { self[DocumentBulkEditConfirmationPresenter.self] = newValue }
    }
}
