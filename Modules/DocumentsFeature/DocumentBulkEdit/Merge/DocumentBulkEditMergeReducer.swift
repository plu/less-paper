import ApiInterface
import Components
import ComposableArchitecture
import Foundation

@Reducer
public struct DocumentBulkEditMergeReducer: Sendable {

    public enum Action: BindableAction, ViewAction {
        case binding(BindingAction<State>)
        case delegate(Delegate)
        case documentsLoaded([Document])
        case error(Error)
        case mergeConfirmed
        case view(View)

        @CasePathable
        public enum Delegate {
            case documentsMerged
        }

        public enum View {
            case closeButtonTapped
            case mergeButtonTapped
            case moved(IndexSet, Int)
            case onAppear
        }
    }

    @ObservableState
    public struct State: Equatable {

        // Read off the fetched documents rather than the selection: a document deleted on the
        // server between selecting and opening the sheet is not in `documents`, and merging what is
        // left of a two-document selection would silently copy a single document.
        var canMerge: Bool {
            documents.count >= minimumDocumentCount
        }

        var deleteOriginals = false

        var documents: [Document] = []

        var isLoading = false

        var isSaving = false

        let selectedDocuments: Set<Document.Id>

        let server: Server

        let sort: DocumentFilterInput.SortFilter
    }

    public var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case let .documentsLoaded(documents):
                state.documents = documents
                state.isLoading = false
                return .none
            case let .error(error):
                state.isLoading = false
                state.isSaving = false
                return .toast(error)
            case .mergeConfirmed:
                guard state.canMerge else {
                    return .none
                }
                state.isSaving = true
                return .runMerge(
                    deleteOriginals: state.deleteOriginals,
                    documents: state.documents.map(\.id),
                    server: state.server
                )
            case let .view(viewAction):
                switch viewAction {
                case .closeButtonTapped:
                    return .runDismiss()
                case .mergeButtonTapped:
                    guard state.canMerge else {
                        return .none
                    }
                    return .runConfirmMerge(
                        deleteOriginals: state.deleteOriginals,
                        documentCount: state.documents.count
                    )
                case let .moved(source, destination):
                    state.documents.move(fromOffsets: source, toOffset: destination)
                    return .none
                case .onAppear:
                    guard state.documents.isEmpty else {
                        return .none
                    }
                    state.isLoading = true
                    return .runGetDocumentsByIds(
                        ids: state.selectedDocuments,
                        server: state.server,
                        sort: state.sort
                    )
                }
            case .binding, .delegate:
                return .none
            }
        }
    }

    public init() {}
}

private let minimumDocumentCount = 2
