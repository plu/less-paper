@testable import DocumentsFeature

import ApiInterface
import ComposableArchitecture
import Foundation
import Testing
import TestSupport

@MainActor
@Suite(
    .testDependencies()
)
struct DocumentSearchReducerTests {

    @Test
    func view_searchTextChanged_debouncesThenSearches() async throws {
        let clock = TestClock()
        let output = GlobalSearchOutput.testValue(tags: [.testValue(id: 7, name: "Manual")])

        let store = TestStore(initialState: DocumentSearchReducer.State.testValue()) {
            DocumentSearchReducer()
        } withDependencies: {
            $0.continuousClock = clock
            $0.globalSearch.execute = { _, _ in output }
        }

        await store.send(.view(.searchTextChanged("man"))) {
            $0.searchText = "man"
            $0.isLoading = true
        }

        await clock.advance(by: .milliseconds(400))
        await store.receive(\.searchDebounced)
        await store.receive(\.results) {
            $0.isLoading = false
            $0.results = output
        }
    }

    // Under three characters the endpoint answers 400, so the request is never made at all.
    @Test
    func view_searchTextChanged_shortQueryMakesNoRequest() async throws {
        let clock = TestClock()

        let store = TestStore(initialState: DocumentSearchReducer.State.testValue(
            results: .testValue(tags: [.testValue(id: 7, name: "Manual")])
        )) {
            DocumentSearchReducer()
        } withDependencies: {
            $0.continuousClock = clock
            $0.globalSearch.execute = { _, _ in
                Issue.record("no request may be made below the minimum query length")
                return .testValue()
            }
        }

        await store.send(.view(.searchTextChanged("ma"))) {
            $0.searchText = "ma"
            $0.isLoading = false
            $0.results = nil
        }

        await clock.advance(by: .milliseconds(400))
    }

    // Proves the debounce and the request share one cancel id: a request left mid-flight when the
    // query drops below the minimum must not be allowed to land later. Splitting them into two ids
    // leaves this in-flight request uncancelled, and it delivers once the clock below unblocks it.
    @Test
    func view_searchTextChanged_shortQueryCancelsAnInFlightRequest() async throws {
        let clock = TestClock()
        let output = GlobalSearchOutput.testValue(tags: [.testValue(id: 7, name: "Manual")])

        let store = TestStore(initialState: DocumentSearchReducer.State.testValue()) {
            DocumentSearchReducer()
        } withDependencies: {
            $0.continuousClock = clock
            $0.globalSearch.execute = { _, _ in
                try await clock.sleep(for: .seconds(60))
                return output
            }
        }

        await store.send(.view(.searchTextChanged("man"))) {
            $0.searchText = "man"
            $0.isLoading = true
        }
        await clock.advance(by: .milliseconds(400))
        await store.receive(\.searchDebounced)

        await store.send(.view(.searchTextChanged("ma"))) {
            $0.searchText = "ma"
            $0.isLoading = false
            $0.results = nil
        }

        await clock.advance(by: .seconds(60))
        await store.finish()
    }

    @Test
    func view_searchTextChanged_coalescesKeystrokes() async throws {
        let clock = TestClock()
        let output = GlobalSearchOutput.testValue(tags: [.testValue(id: 7, name: "Manual")])
        let queries = LockIsolated([String]())

        let store = TestStore(initialState: DocumentSearchReducer.State.testValue()) {
            DocumentSearchReducer()
        } withDependencies: {
            $0.continuousClock = clock
            $0.globalSearch.execute = { query, _ in
                queries.withValue { $0.append(query) }
                return output
            }
        }

        await store.send(.view(.searchTextChanged("man"))) {
            $0.searchText = "man"
            $0.isLoading = true
        }
        await clock.advance(by: .milliseconds(200))
        await store.send(.view(.searchTextChanged("manu"))) {
            $0.searchText = "manu"
        }
        await clock.advance(by: .milliseconds(400))

        await store.receive(\.searchDebounced)
        await store.receive(\.results) {
            $0.isLoading = false
            $0.results = output
        }

        #expect(queries.value == ["manu"])
    }

    // The query is read when searchDebounced lands rather than captured when it is scheduled, so a
    // keystroke inside the window searches for what is on screen, not what was.
    @Test
    func searchDebounced_usesTheTrimmedQuery() async throws {
        let clock = TestClock()
        let queries = LockIsolated([String]())

        let store = TestStore(initialState: DocumentSearchReducer.State.testValue()) {
            DocumentSearchReducer()
        } withDependencies: {
            $0.continuousClock = clock
            $0.globalSearch.execute = { query, _ in
                queries.withValue { $0.append(query) }
                return .testValue()
            }
        }

        await store.send(.view(.searchTextChanged("  manual  "))) {
            $0.searchText = "  manual  "
            $0.isLoading = true
        }
        await clock.advance(by: .milliseconds(400))
        await store.receive(\.searchDebounced)
        await store.receive(\.results) {
            $0.isLoading = false
            $0.results = .testValue()
        }

        #expect(queries.value == ["manual"])
    }

    // A failed lookup must not blank the results out from under someone still reading them.
    @Test
    func error_keepsPreviousResults() async throws {
        let clock = TestClock()
        let previous = GlobalSearchOutput.testValue(tags: [.testValue(id: 7, name: "Manual")])

        let store = TestStore(initialState: DocumentSearchReducer.State.testValue(
            results: previous
        )) {
            DocumentSearchReducer()
        } withDependencies: {
            $0.continuousClock = clock
            $0.globalSearch.execute = { _, _ in throw SearchTestError.failed }
        }

        await store.send(.view(.searchTextChanged("man"))) {
            $0.searchText = "man"
            $0.isLoading = true
        }

        await clock.advance(by: .milliseconds(400))
        await store.receive(\.searchDebounced)
        await store.receive(\.error) {
            $0.isLoading = false
            $0.error = SearchTestError.failed.localizedDescription
        }

        #expect(store.state.results == previous)
    }

    // The one tap that leaves the query standing: the detail is pushed over the results and
    // coming back has to return the user to them.
    @Test
    func view_documentTapped_delegatesAndKeepsTheQuery() async throws {
        let document = Document.testValue(id: 8)
        let results = GlobalSearchOutput.testValue(documents: [document])
        let store = TestStore(initialState: DocumentSearchReducer.State.testValue(
            results: results,
            searchText: "man"
        )) {
            DocumentSearchReducer()
        }

        await store.send(.view(.documentTapped(document)))
        await store.receive(\.delegate.documentTapped, document.id)

        #expect(store.state.searchText == "man")
        #expect(store.state.results == results)
    }

    // Each of the six below is the same shape: the filter the tap composes, and the clear that
    // ends the search. They start from a query because that is the only way a result can be on
    // screen to tap.
    @Test
    func view_tagTapped_delegatesAFilterAndClears() async throws {
        let tag = Tag.testValue(id: 7, name: "Manual")
        let store = searchingStore()

        await store.send(.view(.tagTapped(tag))) {
            $0.clearedQuery = "man"
            $0.dismissalCount = 1
            $0.results = nil
            $0.searchText = ""
        }
        await store.receive(\.delegate.filterRequested, .searchResult(tag: tag))

        #expect(!store.state.hasQuery)
    }

    @Test
    func view_correspondentTapped_delegatesAFilterAndClears() async throws {
        let correspondent = Correspondent.testValue(id: 4)
        let store = searchingStore()

        await store.send(.view(.correspondentTapped(correspondent))) {
            $0.clearedQuery = "man"
            $0.dismissalCount = 1
            $0.results = nil
            $0.searchText = ""
        }
        await store.receive(\.delegate.filterRequested, .searchResult(correspondent: correspondent))
    }

    @Test
    func view_customFieldTapped_delegatesAFilterAndClears() async throws {
        let customField = CustomField.testValue(id: 2)
        let store = searchingStore()

        await store.send(.view(.customFieldTapped(customField))) {
            $0.clearedQuery = "man"
            $0.dismissalCount = 1
            $0.results = nil
            $0.searchText = ""
        }
        await store.receive(\.delegate.filterRequested, .searchResult(customField: customField))
    }

    @Test
    func view_documentTypeTapped_delegatesAFilterAndClears() async throws {
        let documentType = DocumentType.testValue(id: 5)
        let store = searchingStore()

        await store.send(.view(.documentTypeTapped(documentType))) {
            $0.clearedQuery = "man"
            $0.dismissalCount = 1
            $0.results = nil
            $0.searchText = ""
        }
        await store.receive(\.delegate.filterRequested, .searchResult(documentType: documentType))
    }

    @Test
    func view_storagePathTapped_delegatesAFilterAndClears() async throws {
        let storagePath = StoragePath.testValue(id: 6)
        let store = searchingStore()

        await store.send(.view(.storagePathTapped(storagePath))) {
            $0.clearedQuery = "man"
            $0.dismissalCount = 1
            $0.results = nil
            $0.searchText = ""
        }
        await store.receive(\.delegate.filterRequested, .searchResult(storagePath: storagePath))
    }

    @Test
    func view_savedViewTapped_delegatesAndClears() async throws {
        let savedView = SavedView.testValue()
        let store = searchingStore()

        await store.send(.view(.savedViewTapped(savedView))) {
            $0.clearedQuery = "man"
            $0.dismissalCount = 1
            $0.results = nil
            $0.searchText = ""
        }
        await store.receive(\.delegate.savedViewTapped, savedView)
    }

    // The debounce and the request share `CancelID.search`, so clearing has to cancel as well as
    // wipe: a response for the query just thrown away would otherwise land and repopulate it.
    @Test
    func view_tagTapped_cancelsAnInFlightSearch() async throws {
        let clock = TestClock()
        let tag = Tag.testValue(id: 7, name: "Manual")
        let store = TestStore(initialState: DocumentSearchReducer.State.testValue()) {
            DocumentSearchReducer()
        } withDependencies: {
            $0.continuousClock = clock
            $0.globalSearch.execute = { _, _ in
                try await clock.sleep(for: .seconds(60))
                return .testValue(tags: [tag])
            }
        }

        await store.send(.view(.searchTextChanged("man"))) {
            $0.searchText = "man"
            $0.isLoading = true
        }
        await clock.advance(by: .milliseconds(400))
        await store.receive(\.searchDebounced)

        await store.send(.view(.tagTapped(tag))) {
            $0.clearedQuery = "man"
            $0.dismissalCount = 1
            $0.isLoading = false
            $0.searchText = ""
        }
        await store.receive(\.delegate.filterRequested)

        await clock.advance(by: .seconds(60))
        await store.finish()
    }

    // Cancel is the whole way out — one tap back to the document list — rather than the field's
    // `X`, which only wipes the text and leaves the user in the field with the keyboard up.
    @Test
    func view_cancelButtonTapped_clearsTheQueryAndResults() async throws {
        let store = TestStore(initialState: DocumentSearchReducer.State.testValue(
            error: "offline",
            isLoading: true,
            results: .testValue(tags: [.testValue(id: 7, name: "Manual")]),
            searchText: "manual"
        )) {
            DocumentSearchReducer()
        }

        await store.send(.view(.cancelButtonTapped)) {
            $0.clearedQuery = "manual"
            $0.dismissalCount = 1
            $0.error = nil
            $0.isLoading = false
            $0.results = nil
            $0.searchText = ""
        }

        #expect(!store.state.hasQuery)
    }

    @Test
    func view_cancelButtonTapped_cancelsAnInFlightSearch() async throws {
        let clock = TestClock()
        let store = TestStore(initialState: DocumentSearchReducer.State.testValue()) {
            DocumentSearchReducer()
        } withDependencies: {
            $0.continuousClock = clock
            $0.globalSearch.execute = { _, _ in
                try await clock.sleep(for: .seconds(60))
                return .testValue(tags: [.testValue(id: 7, name: "Manual")])
            }
        }

        await store.send(.view(.searchTextChanged("man"))) {
            $0.searchText = "man"
            $0.isLoading = true
        }
        await clock.advance(by: .milliseconds(400))
        await store.receive(\.searchDebounced)

        await store.send(.view(.cancelButtonTapped)) {
            $0.clearedQuery = "man"
            $0.dismissalCount = 1
            $0.isLoading = false
            $0.searchText = ""
        }

        await clock.advance(by: .seconds(60))
        await store.finish()
    }

    // The delegate still carries the query the user typed, even though state no longer holds it:
    // the filter is composed from what is committed, not from what the field is left showing.
    @Test
    func view_submitted_delegatesTheQueryAndClearsTheField() async throws {
        let store = TestStore(initialState: DocumentSearchReducer.State.testValue(
            results: .testValue(tags: [.testValue(id: 7, name: "Manual")]),
            searchText: "manual"
        )) {
            DocumentSearchReducer()
        }

        await store.send(.view(.submitted)) {
            $0.clearedQuery = "manual"
            $0.dismissalCount = 1
            $0.results = nil
            $0.searchText = ""
        }
        await store.receive(\.delegate.queryCommitted, "manual")
    }

    // The field's own `X` empties the text and nothing more: the user is still in the field, so
    // the keyboard stays up. `dismissalCount` is what the view watches to know the difference, and
    // an `X` that bumped it would resign focus after every deletion.
    @Test
    func view_searchTextChanged_doesNotCountAsADismissal() async throws {
        let store = TestStore(initialState: DocumentSearchReducer.State.testValue(
            results: .testValue(tags: [.testValue(id: 7, name: "Manual")]),
            searchText: "manual"
        )) {
            DocumentSearchReducer()
        }

        await store.send(.view(.searchTextChanged(""))) {
            $0.results = nil
            $0.searchText = ""
        }

        #expect(store.state.dismissalCount == 0)
    }

    // Submitting two characters would put a filter on screen the results list never showed.
    @Test
    func view_submitted_ignoresAShortQuery() async throws {
        let store = TestStore(initialState: DocumentSearchReducer.State.testValue(
            searchText: "ma"
        )) {
            DocumentSearchReducer()
        }

        await store.send(.view(.submitted))
    }

    // The write nobody makes on purpose. SwiftUI pushes the field's old text back through the
    // binding as the commit empties it and focus is resigned, and accepting it puts the results
    // back over the documents the commit just fetched. Worse, the commit's own
    // `runCancelSearch` shares `CancelID.search` with the debounce that write starts — so when
    // the cancel lands second, `isLoading` is left true with nothing in flight, which is a
    // spinner that never resolves.
    @Test
    func view_submitted_ignoresTheFieldWritingItsOldQueryBack() async throws {
        let store = TestStore(initialState: DocumentSearchReducer.State.testValue(
            results: .testValue(tags: [.testValue(id: 7, name: "Manual")]),
            searchText: "Sonos"
        )) {
            DocumentSearchReducer()
        } withDependencies: {
            $0.continuousClock = TestClock()
            $0.globalSearch.execute = { _, _ in
                Issue.record("a write-back of the committed query must not start a new search")
                return .testValue()
            }
        }
        store.exhaustivity = .off

        await store.send(.view(.submitted))
        await store.receive(\.delegate.queryCommitted)

        await store.send(.view(.searchTextChanged("Sonos"))) {
            $0.clearedQuery = nil
        }

        #expect(store.state.searchText == "")
        #expect(!store.state.isLoading)
        #expect(!store.state.hasQuery)
    }

    @Test
    func view_cancelButtonTapped_ignoresTheFieldWritingItsOldQueryBack() async throws {
        let store = TestStore(initialState: DocumentSearchReducer.State.testValue(
            searchText: "Sonos"
        )) {
            DocumentSearchReducer()
        } withDependencies: {
            $0.continuousClock = TestClock()
            $0.globalSearch.execute = { _, _ in
                Issue.record("a write-back of the cancelled query must not start a new search")
                return .testValue()
            }
        }
        store.exhaustivity = .off

        await store.send(.view(.cancelButtonTapped))
        await store.send(.view(.searchTextChanged("Sonos")))

        #expect(store.state.searchText == "")
        #expect(!store.state.isLoading)
    }

    // Swallowed exactly once, and only as a whole: retyping the committed query has to work, and
    // its first character is what says this is a person rather than a stale binding.
    @Test
    func view_searchTextChanged_acceptsTheSameQueryTypedAgain() async throws {
        let clock = TestClock()
        let output = GlobalSearchOutput.testValue(tags: [.testValue(id: 7, name: "Manual")])
        let store = TestStore(initialState: DocumentSearchReducer.State.testValue(
            searchText: "Sonos"
        )) {
            DocumentSearchReducer()
        } withDependencies: {
            $0.continuousClock = clock
            $0.globalSearch.execute = { _, _ in output }
        }
        store.exhaustivity = .off

        await store.send(.view(.cancelButtonTapped))

        await store.send(.view(.searchTextChanged("S")))
        await store.send(.view(.searchTextChanged("So")))
        await store.send(.view(.searchTextChanged("Sonos")))

        await clock.advance(by: .milliseconds(400))
        await store.receive(\.searchDebounced)
        await store.receive(\.results)

        #expect(store.state.results == output)
    }

    private func searchingStore() -> TestStoreOf<DocumentSearchReducer> {
        TestStore(initialState: DocumentSearchReducer.State.testValue(
            results: .testValue(tags: [.testValue(id: 7, name: "Manual")]),
            searchText: "man"
        )) {
            DocumentSearchReducer()
        }
    }
}

private enum SearchTestError: Error {
    case failed
}
