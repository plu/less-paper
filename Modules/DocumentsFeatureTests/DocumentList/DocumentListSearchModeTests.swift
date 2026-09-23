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
struct DocumentListSearchModeTests {

    // The whole switch between the two things the list can be. Three characters is the server's
    // own minimum, so the list shows results exactly when a request would be made.
    @Test
    func isSearching_followsTheMinimumQueryLength() async throws {
        #expect(!DocumentListReducer.State.testValue(search: .testValue(searchText: "")).isSearching)
        #expect(!DocumentListReducer.State.testValue(search: .testValue(searchText: "ma")).isSearching)
        #expect(DocumentListReducer.State.testValue(search: .testValue(searchText: "man")).isSearching)
        #expect(!DocumentListReducer.State.testValue(search: .testValue(searchText: "  ma  ")).isSearching)
    }

    // Nothing to select and nothing a bulk edit could mean: the rows on screen are tags and
    // correspondents. The unsearched case is the control — permissions are unread here, which
    // `ServerPermissions.can` answers as allowed.
    @Test
    func canSelect_isOffWhileSearching() async throws {
        #expect(DocumentListReducer.State.testValue().canSelect)
        #expect(!DocumentListReducer.State.testValue(
            search: .testValue(searchText: "man")
        ).canSelect)
    }

    // Selection mode and search results cannot both be on screen, and the user typing is the later
    // of the two intents.
    @Test
    func search_searchTextChanged_leavesSelectionMode() async throws {
        let store = TestStore(initialState: DocumentListReducer.State.testValue(
            documentSelection: .testValue(isActive: true)
        )) {
            DocumentListReducer()
        } withDependencies: {
            $0.continuousClock = TestClock()
        }
        store.exhaustivity = .off

        await store.send(.search(.view(.searchTextChanged("man")))) {
            $0.documentSelection.isActive = false
        }
    }

    @Test
    func search_searchTextChanged_leavesSelectionAloneBelowTheMinimum() async throws {
        let store = TestStore(initialState: DocumentListReducer.State.testValue(
            documentSelection: .testValue(isActive: true)
        )) {
            DocumentListReducer()
        }
        store.exhaustivity = .off

        await store.send(.search(.view(.searchTextChanged("ma"))))

        #expect(store.state.documentSelection.isActive)
    }

    // Pulling on a list of search results would refetch documents that are not the rows being
    // pulled.
    @Test
    func view_onRefresh_doesNothingWhileSearching() async throws {
        let store = TestStore(initialState: DocumentListReducer.State.testValue(
            search: .testValue(searchText: "man")
        )) {
            DocumentListReducer()
        } withDependencies: {
            $0.getDocuments.execute = { _, _ in
                Issue.record("pull-to-refresh must not refetch while search results are showing")
                return .testValue()
            }
        }

        await store.send(.view(.onRefresh))
    }

    // A document result is the one tap that leaves the query alone: the detail is pushed over the
    // results and coming back has to land the user back on them.
    @Test
    func search_delegate_documentTapped_keepsTheQuery() async throws {
        let store = TestStore(initialState: DocumentListReducer.State.testValue(
            search: .testValue(searchText: "man")
        )) {
            DocumentListReducer()
        }
        store.exhaustivity = .off

        await store.send(.search(.delegate(.documentTapped(Document.Id(rawValue: 1)))))
        await store.receive(\.openDocument)

        #expect(store.state.isSearching)
    }

    // Everything else applies a filter, and the child clears the field as it delegates — which is
    // what drops the list back to the documents the filter produced.
    @Test
    func search_tagTapped_appliesTheFilterAndLeavesSearchMode() async throws {
        let tag = Tag.testValue(id: 7, name: "Manual")
        let store = TestStore(initialState: DocumentListReducer.State.testValue(
            search: .testValue(
                results: .testValue(tags: [tag]),
                searchText: "man"
            )
        )) {
            DocumentListReducer()
        } withDependencies: {
            $0.getDocuments.execute = { _, _ in .testValue() }
        }
        store.exhaustivity = .off

        await store.send(.search(.view(.tagTapped(tag))))
        await store.receive(\.search.delegate.filterRequested)

        #expect(!store.state.isSearching)
        #expect(store.state.filter.input == .searchResult(tag: tag))
    }

    // `clearForPendingFetch`: the rows the filter replaces go at once rather than sitting under a
    // filter that no longer describes them, and `isLoaded` stays false so the list spins.
    @Test
    func search_delegate_filterRequested_clearsTheRowsWhileTheFetchRuns() async throws {
        let tag = Tag.testValue(id: 7, name: "Manual")
        let store = TestStore(initialState: DocumentListReducer.State.testValue(
            isLoaded: true
        )) {
            DocumentListReducer()
        } withDependencies: {
            $0.getDocuments.execute = { _, _ in .testValue() }
        }
        store.exhaustivity = .off

        await store.send(.search(.delegate(.filterRequested(.searchResult(tag: tag))))) {
            $0.documents = []
            $0.isLoaded = false
            $0.totalNumberOfDocuments = 0
        }
    }

    @Test
    func search_submitted_appliesATitleAndContentFilterAndLeavesSearchMode() async throws {
        let store = TestStore(initialState: DocumentListReducer.State.testValue(
            search: .testValue(searchText: "manual")
        )) {
            DocumentListReducer()
        } withDependencies: {
            $0.getDocuments.execute = { _, _ in .testValue() }
        }
        store.exhaustivity = .off

        await store.send(.search(.view(.submitted)))
        await store.receive(\.search.delegate.queryCommitted)

        #expect(!store.state.isSearching)
        #expect(store.state.filter.input.searchType == .titleContent)
        #expect(store.state.filter.input.searchValue == "manual")
    }

    @Test
    func search_cancelButtonTapped_returnsToTheDocumentList() async throws {
        let store = TestStore(initialState: DocumentListReducer.State.testValue(
            search: .testValue(
                results: .testValue(tags: [.testValue(id: 7, name: "Manual")]),
                searchText: "manual"
            )
        )) {
            DocumentListReducer()
        }
        store.exhaustivity = .off

        await store.send(.search(.view(.cancelButtonTapped)))

        #expect(!store.state.isSearching)
        #expect(store.state.search.results == nil)
    }
}
