import ApiInterface
import Components
import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
struct DocumentBulkEditConfirmationPresenter: Sendable {

    /// Presents the confirmation popup and suspends until the user confirms or cancels
    var present: @Sendable (_ message: LocalizedStringResource) async -> Bool = { _ in false }

    /// Presents the tag confirmation popup and suspends until the user confirms or cancels
    var presentTags: @Sendable (
        _ addTags: [Tag],
        _ documentCount: Int,
        _ removeTags: [Tag]
    ) async -> Bool = { _, _, _ in false }
}

extension DocumentBulkEditConfirmationPresenter: TestDependencyKey {

    static let previewValue = Self(
        present: { _ in false },
        presentTags: { _, _, _ in false }
    )

    static let testValue = Self()
}

extension DocumentBulkEditConfirmationPresenter: DependencyKey {

    static let liveValue = Self(
        present: present(message:),
        presentTags: presentTags(addTags:documentCount:removeTags:)
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

    static func presentTags(
        addTags: [Tag],
        documentCount: Int,
        removeTags: [Tag]
    ) async -> Bool {
        @Dependency(\.popupPresenter)
        var popupPresenter

        return await popupPresenter.present { resolve in
            ConfirmationPopupView(
                title: .confirmAssignment,
                cancel: { resolve(false) },
                confirm: { resolve(true) }
            ) {
                DocumentBulkEditTagsConfirmationView(
                    addTags: addTags,
                    documentCount: documentCount,
                    removeTags: removeTags
                )
            }
        } ?? false
    }
}

extension DependencyValues {

    var documentBulkEditConfirmation: DocumentBulkEditConfirmationPresenter {
        get { self[DocumentBulkEditConfirmationPresenter.self] }
        set { self[DocumentBulkEditConfirmationPresenter.self] = newValue }
    }
}
