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

    @Test
    func view_documentTapped_delegates() async throws {
        let document = Document.testValue(id: 8)
        let store = TestStore(initialState: DocumentSearchReducer.State.testValue()) {
            DocumentSearchReducer()
        }

        await store.send(.view(.documentTapped(document)))
        await store.receive(\.delegate.documentTapped, document.id)
    }

    @Test
    func view_tagTapped_delegatesAFilter() async throws {
        let tag = Tag.testValue(id: 7, name: "Manual")
        let store = TestStore(initialState: DocumentSearchReducer.State.testValue()) {
            DocumentSearchReducer()
        }

        await store.send(.view(.tagTapped(tag)))
        await store.receive(\.delegate.filterRequested, .searchResult(tag: tag))
    }

    @Test
    func view_correspondentTapped_delegatesAFilter() async throws {
        let correspondent = Correspondent.testValue(id: 4)
        let store = TestStore(initialState: DocumentSearchReducer.State.testValue()) {
            DocumentSearchReducer()
        }

        await store.send(.view(.correspondentTapped(correspondent)))
        await store.receive(\.delegate.filterRequested, .searchResult(correspondent: correspondent))
    }

    @Test
    func view_customFieldTapped_delegatesAFilter() async throws {
        let customField = CustomField.testValue(id: 2)
        let store = TestStore(initialState: DocumentSearchReducer.State.testValue()) {
            DocumentSearchReducer()
        }

        await store.send(.view(.customFieldTapped(customField)))
        await store.receive(\.delegate.filterRequested, .searchResult(customField: customField))
    }

    @Test
    func view_documentTypeTapped_delegatesAFilter() async throws {
        let documentType = DocumentType.testValue(id: 5)
        let store = TestStore(initialState: DocumentSearchReducer.State.testValue()) {
            DocumentSearchReducer()
        }

        await store.send(.view(.documentTypeTapped(documentType)))
        await store.receive(\.delegate.filterRequested, .searchResult(documentType: documentType))
    }

    @Test
    func view_storagePathTapped_delegatesAFilter() async throws {
        let storagePath = StoragePath.testValue(id: 6)
        let store = TestStore(initialState: DocumentSearchReducer.State.testValue()) {
            DocumentSearchReducer()
        }

        await store.send(.view(.storagePathTapped(storagePath)))
        await store.receive(\.delegate.filterRequested, .searchResult(storagePath: storagePath))
    }

    @Test
    func view_savedViewTapped_delegates() async throws {
        let savedView = SavedView.testValue()
        let store = TestStore(initialState: DocumentSearchReducer.State.testValue()) {
            DocumentSearchReducer()
        }

        await store.send(.view(.savedViewTapped(savedView)))
        await store.receive(\.delegate.savedViewTapped, savedView)
    }

    @Test
    func view_submitted_delegatesTheQuery() async throws {
        let store = TestStore(initialState: DocumentSearchReducer.State.testValue(
            searchText: "manual"
        )) {
            DocumentSearchReducer()
        }

        await store.send(.view(.submitted))
        await store.receive(\.delegate.queryCommitted, "manual")
    }

    // Submitting two characters would put a filter on screen the results overlay never showed.
    @Test
    func view_submitted_ignoresAShortQuery() async throws {
        let store = TestStore(initialState: DocumentSearchReducer.State.testValue(
            searchText: "ma"
        )) {
            DocumentSearchReducer()
        }

        await store.send(.view(.submitted))
    }
}

private enum SearchTestError: Error {
    case failed
}
