import ApiInterface
import Components
import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
struct DocumentBulkEditConfirmationPresenter: Sendable {

    var present: @Sendable (_ message: LocalizedStringResource) async -> Bool = { _ in false }

    var presentMerge: @Sendable (
        _ deleteOriginals: Bool,
        _ documentCount: Int
    ) async -> Bool = { _, _ in false }

    var presentTags: @Sendable (
        _ addTags: [Tag],
        _ documentCount: Int,
        _ removeTags: [Tag]
    ) async -> Bool = { _, _, _ in false }

    var presentTitle: @Sendable (_ documentCount: Int) async -> Bool = { _ in false }
}

extension DocumentBulkEditConfirmationPresenter: TestDependencyKey {

    static let previewValue = Self(
        present: { _ in false },
        presentMerge: { _, _ in false },
        presentTags: { _, _, _ in false },
        presentTitle: { _ in false }
    )

    static let testValue = Self()
}

extension DocumentBulkEditConfirmationPresenter: DependencyKey {

    static let liveValue = Self(
        present: present(message:),
        presentMerge: presentMerge(deleteOriginals:documentCount:),
        presentTags: presentTags(addTags:documentCount:removeTags:),
        presentTitle: presentTitle(documentCount:)
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

    static func presentMerge(deleteOriginals: Bool, documentCount: Int) async -> Bool {
        @Dependency(\.popupPresenter)
        var popupPresenter

        return await popupPresenter.present { resolve in
            ConfirmationPopupView(
                title: .confirmMerge,
                message: deleteOriginals
                    ? .bulkEditMergeDeleteOriginalsConfirmation(documentCount)
                    : .bulkEditMergeConfirmation(documentCount),
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

    static func presentTitle(documentCount: Int) async -> Bool {
        @Dependency(\.popupPresenter)
        var popupPresenter

        return await popupPresenter.present { resolve in
            ConfirmationPopupView(
                title: .confirmChanges,
                message: .bulkEditTitleConfirmation(documentCount),
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
