import ApiInterface
import Components
import ComposableArchitecture
import Foundation
import IdentifiedCollections

@Reducer
public struct DocumentPickerReducer: Sendable {
    public enum Action: BindableAction, ViewAction {
        case binding(BindingAction<State>)
        case delegate(Delegate)
        case documentsLoaded(IdentifiedArrayOf<Document>)
        case error(Error)
        case searchDebounced
        case view(View)

        @CasePathable
        public enum Delegate: Equatable {
            case selectionChanged([Document.Id])
        }

        public enum View: Equatable {
            case closeButtonTapped
            case documentTapped(Document.Id)
            case onAppear
        }
    }

    @ObservableState
    public struct State: Equatable, Sendable {
        var documents: IdentifiedArrayOf<Document> = []

        var isLoading = false

        var searchText = ""

        // Whole documents rather than ids: the selected rows pin above the results, and they have
        // to keep their titles even once the current query stops returning them.
        var selection: IdentifiedArrayOf<Document> = []

        let server: Server

        // Selected first, then everything the search returned that is not already shown. Without
        // the pinning a document you picked vanishes as soon as you type something else — still in
        // the query, but no longer visible or removable.
        var rows: IdentifiedArrayOf<Document> {
            var rows = selection
            for document in documents where rows[id: document.id] == nil {
                rows.append(document)
            }
            return rows
        }
    }

    public var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding(\.searchText):
                return .runSearchDebounce()
            case let .documentsLoaded(documents):
                state.isLoading = false
                state.documents = documents
                return .none
            case let .error(error):
                state.isLoading = false
                return .toast(error)
            case .searchDebounced:
                state.isLoading = true
                return .runSearch(state)
            case let .view(viewAction):
                switch viewAction {
                case .closeButtonTapped:
                    return .runDismiss()
                case let .documentTapped(id):
                    if state.selection[id: id] != nil {
                        state.selection.remove(id: id)
                    } else if let document = state.rows[id: id] {
                        state.selection.append(document)
                    }
                    return .send(.delegate(.selectionChanged(state.selection.ids.sorted())))
                case .onAppear:
                    state.isLoading = true
                    return .runSearch(state)
                }
            case .binding, .delegate:
                return .none
            }
        }
    }

    public init() {}
}
