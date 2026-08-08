import ApiInterface
import Components
import ComposableArchitecture
import SwiftUI

@Reducer
public struct DocumentSelectionReducer: Sendable {

    public enum Action: BindableAction {
        case binding(BindingAction<State>)
        case documentTapped(Document.Id)
        case error(Error)
        case selectAllLoadedButtonTapped
        case selectAllMatchingButtonTapped
        case selectNoneButtonTapped
        case toggleSelectionModeButtonTapped(DocumentFilter)
    }

    @ObservableState
    public struct State: Equatable {

        var allMatchingDocuments = Set<Document.Id>()

        var filter = DocumentFilter()

        var allLoadedDocuments = Set<Document.Id>()

        var isActive = false

        var isLoading = false

        var selectedDocuments = Set<Document.Id>()

        let server: Server

        var tabBarVisibility: Visibility {
            isActive ? .hidden : .automatic
        }

        init(
            allLoadedDocuments: Set<Document.Id> = .init(),
            allMatchingDocuments: Set<Document.Id> = .init(),
            isActive: Bool = false,
            selectedDocuments: Set<Document.Id> = .init(),
            server: Server
        ) {
            self.allLoadedDocuments = allLoadedDocuments
            self.allMatchingDocuments = allMatchingDocuments
            self.isActive = isActive
            self.selectedDocuments = selectedDocuments
            self.server = server
        }
    }

    public var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case let .documentTapped(document):
                if state.selectedDocuments.contains(document) {
                    state.selectedDocuments.remove(document)
                } else {
                    state.selectedDocuments.insert(document)
                }
                return .none
            case let .error(error):
                return .toast(error)
            case .selectAllLoadedButtonTapped:
                state.selectedDocuments = state.allLoadedDocuments
                return .none
            case .selectAllMatchingButtonTapped:
                guard !state.allMatchingDocuments.isEmpty else {
                    state.isLoading = true
                    return .runGetAllDocumentIds(
                        filterRules: state.filter.input.filterRules,
                        server: state.server
                    )
                }
                state.selectedDocuments = state.allMatchingDocuments
                return .none
            case .selectNoneButtonTapped:
                state.selectedDocuments = []
                return .none
            case let .toggleSelectionModeButtonTapped(filter):
                state.filter = filter
                if state.isActive {
                    state.isActive = false
                    state.selectedDocuments = []
                } else {
                    state.isActive = true
                }
                return .none
            case .binding:
                return .none
            }
        }
    }

    public init() {}
}
