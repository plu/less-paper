import Components
import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
struct DocumentDeleteConfirmationPresenter: Sendable {
    var present: @Sendable (_ documentTitle: String) async -> Bool = { _ in false }
    var presentMany: @Sendable (_ documentCount: Int) async -> Bool = { _ in false }
}

extension DocumentDeleteConfirmationPresenter: TestDependencyKey {

    static let previewValue = Self(
        present: { _ in false },
        presentMany: { _ in false }
    )

    static let testValue = Self()
}

extension DocumentDeleteConfirmationPresenter: DependencyKey {

    static let liveValue = Self(
        present: present(documentTitle:),
        presentMany: presentMany(documentCount:)
    )
}

private extension DocumentDeleteConfirmationPresenter {

    static func present(documentTitle: String) async -> Bool {
        @Dependency(\.popupPresenter)
        var popupPresenter

        return await popupPresenter.present { resolve in
            ConfirmationPopupView(
                title: .deleteDocument,
                message: .deleteConfirmation(documentTitle),
                isDestructive: true,
                cancel: { resolve(false) },
                confirm: { resolve(true) }
            )
        } ?? false
    }

    static func presentMany(documentCount: Int) async -> Bool {
        @Dependency(\.popupPresenter)
        var popupPresenter

        return await popupPresenter.present { resolve in
            ConfirmationPopupView(
                title: .deleteDocuments,
                message: .deleteDocumentsConfirmation(documentCount),
                isDestructive: true,
                cancel: { resolve(false) },
                confirm: { resolve(true) }
            )
        } ?? false
    }
}

extension DependencyValues {

    var documentDeleteConfirmation: DocumentDeleteConfirmationPresenter {
        get { self[DocumentDeleteConfirmationPresenter.self] }
        set { self[DocumentDeleteConfirmationPresenter.self] = newValue }
    }
}
