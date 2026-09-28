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
struct DocumentSearchInboxModeTests {

    // The inbox debounces into a title and content rule on the list itself, so the global search
    // endpoint must never be hit there — not even for a query long enough to search globally.
    @Test
    func view_searchTextChanged_debouncesThenDelegatesWithoutGlobalSearch() async throws {
        let clock = TestClock()

        let store = TestStore(initialState: DocumentSearchReducer.State.testValue(
            isGlobalSearchEnabled: false
        )) {
            DocumentSearchReducer()
        } withDependencies: {
            $0.continuousClock = clock
            $0.globalSearch.execute = { _, _ in
                Issue.record("inbox search must not query the global search endpoint")
                return .testValue()
            }
        }

        await store.send(.view(.searchTextChanged("man"))) {
            $0.searchText = "man"
        }

        await clock.advance(by: .milliseconds(400))
        await store.receive(\.searchDebounced)
        await store.receive(\.delegate.inboxQueryChanged, "man")

        #expect(!store.state.isLoading)
        #expect(store.state.results == nil)
    }

    // GET /documents/ has no minimum length, unlike /api/search/ with its 400 below three
    // characters — so a single character filters the inbox.
    @Test
    func view_searchTextChanged_singleCharacterDelegates() async throws {
        let clock = TestClock()

        let store = TestStore(initialState: DocumentSearchReducer.State.testValue(
            isGlobalSearchEnabled: false
        )) {
            DocumentSearchReducer()
        } withDependencies: {
            $0.continuousClock = clock
            $0.globalSearch.execute = { _, _ in
                Issue.record("inbox search must not query the global search endpoint")
                return .testValue()
            }
        }

        await store.send(.view(.searchTextChanged("i"))) {
            $0.searchText = "i"
        }

        await clock.advance(by: .milliseconds(400))
        await store.receive(\.searchDebounced)
        await store.receive(\.delegate.inboxQueryChanged, "i")
    }

    // An emptied field clears the rule at once rather than debouncing it.
    @Test
    func view_searchTextChanged_emptyClearsAtOnce() async throws {
        let store = TestStore(initialState: DocumentSearchReducer.State.testValue(
            isGlobalSearchEnabled: false,
            searchText: "man"
        )) {
            DocumentSearchReducer()
        } withDependencies: {
            $0.globalSearch.execute = { _, _ in
                Issue.record("inbox search must not query the global search endpoint")
                return .testValue()
            }
        }

        await store.send(.view(.searchTextChanged(""))) {
            $0.searchText = ""
        }
        await store.receive(\.delegate.inboxQueryChanged, "")
    }

    // Live filtering has already applied the query, so submit only puts the keyboard away. The text
    // stays: it is the visible record of the filter the list is showing.
    @Test
    func view_submitted_keepsTheTextAndDelegates() async throws {
        let store = TestStore(initialState: DocumentSearchReducer.State.testValue(
            isGlobalSearchEnabled: false,
            searchText: "man"
        )) {
            DocumentSearchReducer()
        }

        await store.send(.view(.submitted)) {
            $0.dismissalCount = 1
        }
        await store.receive(\.delegate.inboxQueryChanged, "man")

        #expect(store.state.searchText == "man")
    }

    @Test
    func view_cancelButtonTapped_clearsAndDelegatesEmpty() async throws {
        let store = TestStore(initialState: DocumentSearchReducer.State.testValue(
            isGlobalSearchEnabled: false,
            searchText: "man"
        )) {
            DocumentSearchReducer()
        }

        await store.send(.view(.cancelButtonTapped)) {
            $0.clearedQuery = "man"
            $0.dismissalCount = 1
            $0.searchText = ""
        }
        await store.receive(\.delegate.inboxQueryChanged, "")
    }
}
