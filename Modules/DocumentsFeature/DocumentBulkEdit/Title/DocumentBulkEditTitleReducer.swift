import ApiInterface
import Components
import ComposableArchitecture
import Foundation
import Tagged

@Reducer
public struct DocumentBulkEditTitleReducer: Sendable {

    public enum Action: BindableAction, ViewAction {
        case applyConfirmed
        case binding(BindingAction<State>)
        case delegate(Delegate)
        case documentsLoaded([Document])
        case documentsLoadFinished
        case error(Error)
        case progress(completed: Int)
        case saved(failed: Set<Document.Id>)
        case view(View)

        @CasePathable
        public enum Delegate {
            case documentsUpdated(Set<Document.Id>)
        }

        public enum View {
            case applyButtonTapped
            case closeButtonTapped
            case onAppear
            case placeholderTapped(DocumentBulkEditTitlePlaceholder)
            case resetButtonTapped
        }
    }

    public struct Preview: Equatable, Identifiable, Sendable {

        let document: Document

        public var id: Document.Id { document.id }

        let newTitle: String

        var oldTitle: String { document.title }

        var updateInput: UpdateDocumentInput {
            .init(
                archiveSerialNumber: document.archiveSerialNumber,
                correspondent: document.correspondent,
                createdDate: document.created,
                documentType: document.documentType,
                storagePath: document.storagePath,
                tags: document.tags,
                title: newTitle
            )
        }
    }

    @ObservableState
    public struct State: Equatable {

        var changedPreviews: [Preview] {
            previews.filter { $0.newTitle != $0.oldTitle && !$0.newTitle.isEmpty }
        }

        let documents: Set<Document.Id>

        var isEdited: Bool {
            !changedPreviews.isEmpty
        }

        var isLoading = false

        var isSaving = false

        var loadedDocuments: IdentifiedArrayOf<Document> = []

        var previews: [Preview] {
            let parsed = DocumentBulkEditTitleTemplate(text: template)
            return loadedDocuments.map { document in
                Preview(document: document, newTitle: parsed.title(for: document, server: server))
            }
        }

        var progress: Double {
            let total = changedPreviews.count
            guard total > 0 else {
                return 0
            }
            return Double(savedCount) / Double(total)
        }

        var savedCount = 0

        let server: Server

        // Starts as the document's own title, so the field opens on a no-op the user extends —
        // typing a prefix or appending a placeholder — rather than on a blank that would wipe every
        // title if applied.
        var template = DocumentBulkEditTitlePlaceholder.title.rawValue

        public init(
            documents: Set<Document.Id>,
            server: Server
        ) {
            self.documents = documents
            self.server = server
        }
    }

    public var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .applyConfirmed:
                state.isSaving = true
                state.savedCount = 0
                return .runUpdateTitles(
                    previews: state.changedPreviews,
                    server: state.server
                )
            case let .documentsLoaded(documents):
                for document in documents {
                    state.loadedDocuments.updateOrAppend(document)
                }
                return .none
            case .documentsLoadFinished:
                state.isLoading = false
                return .none
            case let .error(error):
                state.isLoading = false
                state.isSaving = false
                return .toast(error)
            case let .progress(completed):
                state.savedCount = completed
                return .none
            case let .saved(failed):
                state.isSaving = false
                // Derived from the documents on screen rather than from `changedPreviews`, so a
                // retry after a partial failure still reports the ids it has just fixed.
                let succeeded = Set(state.loadedDocuments.ids).subtracting(failed)
                guard !failed.isEmpty else {
                    return .merge(
                        .send(.delegate(.documentsUpdated(succeeded))),
                        .runDismiss()
                    )
                }
                state.loadedDocuments.removeAll { !failed.contains($0.id) }
                state.savedCount = 0
                return .merge(
                    .send(.delegate(.documentsUpdated(succeeded))),
                    .toast(Toast.error(String(localized: .bulkEditTitleError(failed.count))))
                )
            case let .view(viewAction):
                switch viewAction {
                case .applyButtonTapped:
                    let documentCount = state.changedPreviews.count
                    guard documentCount > 0 else {
                        return .none
                    }
                    return .runConfirmApply(documentCount: documentCount)
                case .closeButtonTapped:
                    return .runDismiss()
                case .onAppear:
                    state.isLoading = true
                    return .runGetDocumentsByIds(
                        ids: state.documents,
                        server: state.server
                    )
                case let .placeholderTapped(placeholder):
                    state.template += placeholder.rawValue
                    return .none
                case .resetButtonTapped:
                    state.template = DocumentBulkEditTitlePlaceholder.title.rawValue
                    return .none
                }
            case .binding, .delegate:
                return .none
            }
        }
    }

    public init() {}
}
