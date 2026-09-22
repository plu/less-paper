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

    // The field is emptied by the tap itself, which is what lets `.searchable` collapse back off
    // the navigation bar. The query is stashed rather than dropped so refocusing can put it back.
    @Test
    func view_tagTapped_emptiesTheFieldAndStashesTheQuery() async throws {
        let tag = Tag.testValue(id: 7, name: "Manual")
        let store = TestStore(initialState: DocumentSearchReducer.State.testValue(
            results: .testValue(tags: [tag]),
            searchText: "manual"
        )) {
            DocumentSearchReducer()
        }

        await store.send(.view(.tagTapped(tag))) {
            $0.restorableQuery = "manual"
            $0.searchText = ""
        }
        await store.receive(\.delegate.filterRequested, .searchResult(tag: tag))

        // The results outlive the tap: refocusing shows them again while the re-search is in flight.
        #expect(store.state.results == .testValue(tags: [tag]))
    }

    @Test
    func view_documentTapped_emptiesTheFieldAndStashesTheQuery() async throws {
        let document = Document.testValue(id: 8)
        let store = TestStore(initialState: DocumentSearchReducer.State.testValue(
            searchText: "manual"
        )) {
            DocumentSearchReducer()
        }

        await store.send(.view(.documentTapped(document))) {
            $0.restorableQuery = "manual"
            $0.searchText = ""
        }
        await store.receive(\.delegate.documentTapped, document.id)
    }

    // An empty field stashes nothing, so focusing it again restores nothing and searches nothing.
    @Test
    func view_savedViewTapped_delegatesAndStashesNothingForAnEmptyField() async throws {
        let savedView = SavedView.testValue()
        let store = TestStore(initialState: DocumentSearchReducer.State.testValue()) {
            DocumentSearchReducer()
        } withDependencies: {
            $0.globalSearch.execute = { _, _ in
                Issue.record("an empty field has no query to restore")
                return .testValue()
            }
        }

        await store.send(.view(.savedViewTapped(savedView)))
        await store.receive(\.delegate.savedViewTapped, savedView)

        await store.send(.view(.refocused))
    }

    // The other half of the collapse: the term is put back the moment the field is tapped again,
    // and searched straight away so there is something to refine.
    @Test
    func view_refocused_restoresTheStashedQueryAndSearches() async throws {
        let tag = Tag.testValue(id: 7, name: "Manual")
        let output = GlobalSearchOutput.testValue(tags: [tag])
        let queries = LockIsolated([String]())

        let store = TestStore(initialState: DocumentSearchReducer.State.testValue(
            searchText: "manual"
        )) {
            DocumentSearchReducer()
        } withDependencies: {
            $0.globalSearch.execute = { query, _ in
                queries.withValue { $0.append(query) }
                return output
            }
        }

        await store.send(.view(.tagTapped(tag))) {
            $0.restorableQuery = "manual"
            $0.searchText = ""
        }
        await store.receive(\.delegate.filterRequested, .searchResult(tag: tag))

        await store.send(.view(.refocused)) {
            $0.isLoading = true
            $0.restorableQuery = nil
            $0.searchText = "manual"
        }
        await store.receive(\.results) {
            $0.isLoading = false
            $0.results = output
        }

        #expect(queries.value == ["manual"])
    }

    // The stash is consumed, not kept: a later focus with an emptied field must stay empty.
    @Test
    func view_refocused_consumesTheStashedQueryOnce() async throws {
        let tag = Tag.testValue(id: 7, name: "Manual")
        let store = TestStore(initialState: DocumentSearchReducer.State.testValue(
            searchText: "manual"
        )) {
            DocumentSearchReducer()
        } withDependencies: {
            $0.globalSearch.execute = { _, _ in .testValue() }
        }

        await store.send(.view(.tagTapped(tag))) {
            $0.restorableQuery = "manual"
            $0.searchText = ""
        }
        await store.receive(\.delegate.filterRequested, .searchResult(tag: tag))

        await store.send(.view(.refocused)) {
            $0.isLoading = true
            $0.restorableQuery = nil
            $0.searchText = "manual"
        }
        await store.receive(\.results) {
            $0.isLoading = false
            $0.results = .testValue()
        }

        await store.send(.view(.searchTextChanged(""))) {
            $0.searchText = ""
            $0.results = nil
        }
        await store.send(.view(.refocused))
    }

    // Typing is a fresh intent, so a stash left by an earlier tap must not reappear over it.
    @Test
    func view_searchTextChanged_discardsAStashedQuery() async throws {
        let clock = TestClock()
        let tag = Tag.testValue(id: 7, name: "Manual")
        let store = TestStore(initialState: DocumentSearchReducer.State.testValue(
            searchText: "manual"
        )) {
            DocumentSearchReducer()
        } withDependencies: {
            $0.continuousClock = clock
            $0.globalSearch.execute = { _, _ in .testValue() }
        }

        await store.send(.view(.tagTapped(tag))) {
            $0.restorableQuery = "manual"
            $0.searchText = ""
        }
        await store.receive(\.delegate.filterRequested, .searchResult(tag: tag))

        await store.send(.view(.searchTextChanged("invoice"))) {
            $0.isLoading = true
            $0.restorableQuery = nil
            $0.searchText = "invoice"
        }
        await clock.advance(by: .milliseconds(400))
        await store.receive(\.searchDebounced)
        await store.receive(\.results) {
            $0.isLoading = false
            $0.results = .testValue()
        }

        await store.send(.view(.refocused)) {
            $0.isLoading = true
        }
        await store.receive(\.results) {
            $0.isLoading = false
        }
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

    // The return key with no preceding row tap: the latch must leave this path alone.
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

    // Resigning focus after a row tap makes SwiftUI fire a submit the user never made. It needs no
    // latch: the tap has already emptied the field, so the phantom submit commits nothing and the
    // filter the tap applied stands.
    @Test
    func view_submitted_afterARowTapCommitsNothing() async throws {
        let tag = Tag.testValue(id: 7, name: "Manual")
        let store = TestStore(initialState: DocumentSearchReducer.State.testValue(
            searchText: "manual"
        )) {
            DocumentSearchReducer()
        }

        await store.send(.view(.tagTapped(tag))) {
            $0.restorableQuery = "manual"
            $0.searchText = ""
        }
        await store.receive(\.delegate.filterRequested, .searchResult(tag: tag))

        await store.send(.view(.submitted))
    }

    // A deliberate tap on the field is not a keystroke, so the query runs without the debounce.
    @Test
    func view_refocused_searchesImmediately() async throws {
        let clock = TestClock()
        let output = GlobalSearchOutput.testValue(tags: [.testValue(id: 7, name: "Manual")])

        let store = TestStore(initialState: DocumentSearchReducer.State.testValue(
            searchText: "manual"
        )) {
            DocumentSearchReducer()
        } withDependencies: {
            $0.continuousClock = clock
            $0.globalSearch.execute = { _, _ in output }
        }

        await store.send(.view(.refocused)) {
            $0.isLoading = true
        }
        await store.receive(\.results) {
            $0.isLoading = false
            $0.results = output
        }
    }

    @Test
    func view_refocused_usesTheTrimmedQuery() async throws {
        let queries = LockIsolated([String]())

        let store = TestStore(initialState: DocumentSearchReducer.State.testValue(
            searchText: "  manual  "
        )) {
            DocumentSearchReducer()
        } withDependencies: {
            $0.globalSearch.execute = { query, _ in
                queries.withValue { $0.append(query) }
                return .testValue()
            }
        }

        await store.send(.view(.refocused)) {
            $0.isLoading = true
        }
        await store.receive(\.results) {
            $0.isLoading = false
            $0.results = .testValue()
        }

        #expect(queries.value == ["manual"])
    }

    // Focusing an empty field is the ordinary way a search begins, and it must not fire a request.
    @Test
    func view_refocused_ignoresAShortQuery() async throws {
        let store = TestStore(initialState: DocumentSearchReducer.State.testValue(
            searchText: "ma"
        )) {
            DocumentSearchReducer()
        } withDependencies: {
            $0.globalSearch.execute = { _, _ in
                Issue.record("no request may be made below the minimum query length")
                return .testValue()
            }
        }

        await store.send(.view(.refocused))
    }

    // Proves the refocus search shares the cancel id with the debounce: a sleep left pending when
    // the field is tapped must not wake up afterwards and search a second time.
    @Test
    func view_refocused_cancelsAPendingDebounce() async throws {
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

        await store.send(.view(.searchTextChanged("manual"))) {
            $0.searchText = "manual"
            $0.isLoading = true
        }
        await store.send(.view(.refocused))
        await store.receive(\.results) {
            $0.isLoading = false
            $0.results = .testValue()
        }

        await clock.advance(by: .milliseconds(400))
        await store.finish()

        #expect(queries.value == ["manual"])
    }
}

private enum SearchTestError: Error {
    case failed
}
