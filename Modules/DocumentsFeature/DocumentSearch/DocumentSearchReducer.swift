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
            case cancelButtonTapped
            case correspondentTapped(Correspondent)
            case customFieldTapped(CustomField)
            case documentTapped(Document)
            case documentTypeTapped(DocumentType)
            case savedViewTapped(SavedView)
            case searchTextChanged(String)
            case storagePathTapped(StoragePath)
            case submitted
            case tagTapped(Tag)
        }
    }

    @ObservableState
    public struct State: Equatable {

        // The one write the field is not allowed to make. Committing a search empties
        // `searchText` while the UIKit text field still holds the query, and resigning focus
        // pushes that stale value back through the binding — which puts the results back over the
        // documents the commit just fetched, and, when the commit's own cancellation lands on the
        // debounce that write started, leaves `isLoading` true with nothing in flight and a
        // spinner that never resolves. Swallowed exactly once: typing the same query again is a
        // different keystroke and clears the latch on its first character.
        var clearedQuery: String?

        var error: String?

        var isLoading = false

        var results: GlobalSearchOutput?

        var searchText = ""

        let server: Server

        // Bumped by `clearQuery` and by nothing else, which is the field's cue to resign focus.
        // The `X` inside the field empties the text through `searchTextChanged` and deliberately
        // leaves the keyboard up; finishing the search — Cancel, submit, or a result that applies
        // a filter — has to put it away, and none of those are things the field itself can see.
        var dismissalCount = 0

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

        // Every way out of search mode other than opening a document ends here: the list only
        // leaves the results behind when the field is empty, so a filter that has been applied and
        // is visible in the list is not also still being searched for.
        mutating func clearQuery() {
            clearedQuery = trimmedQuery.isEmpty ? nil : searchText
            dismissalCount += 1
            error = nil
            isLoading = false
            results = nil
            searchText = ""
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
            // The field's own clear button only wipes the text, which arrives as a
            // `searchTextChanged("")`. Cancel is the one that also has to drop focus, and that
            // half belongs to the view: there is no focus in state to reset here.
            case .view(.cancelButtonTapped):
                state.clearQuery()
                return .runCancelSearch()
            case let .view(.correspondentTapped(correspondent)):
                return clearThenDelegate(
                    &state,
                    .filterRequested(.searchResult(correspondent: correspondent))
                )
            case let .view(.customFieldTapped(customField)):
                return clearThenDelegate(
                    &state,
                    .filterRequested(.searchResult(customField: customField))
                )
            // The one tap that leaves the query standing: the detail is pushed over the results,
            // and coming back has to return the user to the list they picked from.
            case let .view(.documentTapped(document)):
                return .send(.delegate(.documentTapped(document.id)))
            case let .view(.documentTypeTapped(documentType)):
                return clearThenDelegate(
                    &state,
                    .filterRequested(.searchResult(documentType: documentType))
                )
            case let .view(.savedViewTapped(savedView)):
                return clearThenDelegate(&state, .savedViewTapped(savedView))
            case let .view(.searchTextChanged(searchText)):
                state.clearedQuery = nil
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
                return clearThenDelegate(
                    &state,
                    .filterRequested(.searchResult(storagePath: storagePath))
                )
            case .view(.submitted):
                guard state.hasQuery else {
                    return .none
                }
                let query = state.trimmedQuery
                return clearThenDelegate(&state, .queryCommitted(query))
            case let .view(.tagTapped(tag)):
                return clearThenDelegate(&state, .filterRequested(.searchResult(tag: tag)))
            }
        }
    }

    public init() {}

    // The delegate is composed before the clear so a case that reads the query — `queryCommitted`
    // — still sees it. Merged with the cancel so a debounce or request already scheduled for the
    // query being thrown away cannot land afterwards and repopulate the results.
    private func clearThenDelegate(
        _ state: inout State,
        _ delegate: Action.Delegate
    ) -> Effect<Action> {
        state.clearQuery()
        return .merge(.runCancelSearch(), .send(.delegate(delegate)))
    }
}
