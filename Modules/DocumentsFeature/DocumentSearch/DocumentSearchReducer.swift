import ApiInterface
import ComposableArchitecture
import CorrespondentsFeature
import DocumentTypesFeature
import Foundation
import SavedViewsFeature
import StoragePathsFeature
import TagsFeature

@Reducer
public struct DocumentSearchReducer: Sendable {

    // The endpoint answers `400 Query must be at least 3 characters`, so this is the server's rule
    // rather than a chosen one, and the request is simply not made below it.
    static let minimumQueryLength = 3

    public enum Action: ViewAction {
        case delegate(Delegate)
        case error(Error)
        case results(GlobalSearchOutput)
        case searchDebounced
        case view(View)

        @CasePathable
        public enum Delegate {
            case documentTapped(Document.Id)
            case filterRequested(DocumentFilterInput)
            case queryCommitted(String)
            case savedViewTapped(SavedView)
        }

        public enum View {
            case correspondentTapped(Correspondent)
            case customFieldTapped(CustomField)
            case documentTapped(Document)
            case documentTypeTapped(DocumentType)
            case refocused
            case savedViewTapped(SavedView)
            case searchTextChanged(String)
            case storagePathTapped(StoragePath)
            case submitted
            case tagTapped(Tag)
        }
    }

    @ObservableState
    public struct State: Equatable {

        var error: String?

        var isLoading = false

        var results: GlobalSearchOutput?

        var searchText = ""

        let server: Server

        // Set by every row tap and consumed by the next `submitted`. Resigning the field's focus
        // programmatically makes SwiftUI fire `onSubmit(of: .search)`, so a tap arrives here as its
        // own action immediately followed by a submit the user never made — which would apply the
        // tapped filter and then overwrite it with a plain text search. Not part of `init`: it is a
        // latch the reducer owns, never initial configuration.
        var suppressesNextSubmit = false

        var trimmedQuery: String {
            searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        var hasQuery: Bool {
            trimmedQuery.count >= DocumentSearchReducer.minimumQueryLength
        }

        public init(
            error: String? = nil,
            isLoading: Bool = false,
            results: GlobalSearchOutput? = nil,
            searchText: String = "",
            server: Server
        ) {
            self.error = error
            self.isLoading = isLoading
            self.results = results
            self.searchText = searchText
            self.server = server
        }
    }

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .delegate:
                return .none
            case let .error(error):
                state.isLoading = false
                state.error = error.localizedDescription
                return .none
            case let .results(output):
                state.error = nil
                state.isLoading = false
                state.results = output
                return .none
            // Reading state at delivery rather than capturing it: a keystroke inside the debounce
            // window would otherwise search for text the user has already moved on from.
            case .searchDebounced:
                return .runGlobalSearch(query: state.trimmedQuery, server: state.server)
            case let .view(.correspondentTapped(correspondent)):
                state.suppressesNextSubmit = true
                return .send(.delegate(.filterRequested(.searchResult(correspondent: correspondent))))
            case let .view(.customFieldTapped(customField)):
                state.suppressesNextSubmit = true
                return .send(.delegate(.filterRequested(.searchResult(customField: customField))))
            case let .view(.documentTapped(document)):
                state.suppressesNextSubmit = true
                return .send(.delegate(.documentTapped(document.id)))
            case let .view(.documentTypeTapped(documentType)):
                state.suppressesNextSubmit = true
                return .send(.delegate(.filterRequested(.searchResult(documentType: documentType))))
            case let .view(.savedViewTapped(savedView)):
                state.suppressesNextSubmit = true
                return .send(.delegate(.savedViewTapped(savedView)))
            // No debounce: a deliberate tap on the field is not a keystroke, so there is nothing
            // to coalesce. Shares CancelID.search with the debounce, so a sleep or request left
            // pending by earlier typing cannot land on top of this one.
            case .view(.refocused):
                guard state.hasQuery else {
                    return .none
                }
                state.error = nil
                state.isLoading = true
                return .runGlobalSearch(query: state.trimmedQuery, server: state.server)
            case let .view(.searchTextChanged(searchText)):
                state.searchText = searchText
                guard state.hasQuery else {
                    state.error = nil
                    state.isLoading = false
                    state.results = nil
                    return .runCancelSearch()
                }
                state.error = nil
                state.isLoading = true
                return .runSearchDebounce()
            case let .view(.storagePathTapped(storagePath)):
                state.suppressesNextSubmit = true
                return .send(.delegate(.filterRequested(.searchResult(storagePath: storagePath))))
            case .view(.submitted):
                guard !state.suppressesNextSubmit else {
                    state.suppressesNextSubmit = false
                    return .none
                }
                guard state.hasQuery else {
                    return .none
                }
                return .send(.delegate(.queryCommitted(state.trimmedQuery)))
            case let .view(.tagTapped(tag)):
                state.suppressesNextSubmit = true
                return .send(.delegate(.filterRequested(.searchResult(tag: tag))))
            }
        }
    }

    public init() {}
}
