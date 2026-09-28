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
struct DocumentListInboxSearchTests {

    // The inbox bar filters the rows in place, so a query there must never flip the list into the
    // search-results branch the documents tab takes.
    @Test
    func isSearching_staysOffWithAnInboxQuery() async throws {
        #expect(!DocumentListReducer.State.testValue(
            filter: .testValue(isInbox: true),
            search: .testValue(isGlobalSearchEnabled: false, searchText: "manual")
        ).isSearching)
        #expect(DocumentListReducer.State.testValue(
            search: .testValue(searchText: "manual")
        ).isSearching)
    }

    // Selection stays available while the inbox filters: the rows on screen are still documents,
    // unlike the tag and correspondent rows of the documents tab results.
    @Test
    func search_searchTextChanged_leavesSelectionModeAlone() async throws {
        let store = TestStore(initialState: DocumentListReducer.State.testValue(
            documentSelection: .testValue(isActive: true),
            filter: .testValue(isInbox: true),
            search: .testValue(isGlobalSearchEnabled: false)
        )) {
            DocumentListReducer()
        } withDependencies: {
            $0.continuousClock = TestClock()
        }
        store.exhaustivity = .off

        await store.send(.search(.view(.searchTextChanged("man"))))

        #expect(store.state.documentSelection.isActive)
    }

    // The whole point: the title and content rule joins the inbox tag rule instead of replacing it.
    @Test
    func search_delegate_inboxQueryChanged_filtersTogetherWithTheInboxTags() async throws {
        let inboxTag = Tag.testValue(id: 104, name: "Inbox")
        let filterRulesUsed = LockIsolated<[FilterRule]?>(nil)

        let store = TestStore(initialState: DocumentListReducer.State.testValue(
            filter: .testValue(
                input: .testValue(tag: .init(rule: .any, selection: .init(any: [inboxTag]))),
                isInbox: true
            ),
            search: .testValue(isGlobalSearchEnabled: false)
        )) {
            DocumentListReducer()
        } withDependencies: {
            $0.getDocuments.execute = { input, _ in
                filterRulesUsed.setValue(input.filterRules)
                return .testValue(count: 1, results: [.testValue()])
            }
        }
        store.exhaustivity = .off

        await store.send(.search(.delegate(.inboxQueryChanged("inv")))) {
            $0.filter.input.searchType = .titleContent
            $0.filter.input.searchValue = "inv"
            $0.isLoadingMore = false
        }
        await store.receive(\.replaceDocuments)
        await store.receive(\.binding, .set(\.isLoaded, true))

        #expect(filterRulesUsed.value == [
            .init(ruleType: .titleContent, value: "inv"),
            .init(ruleType: .hasTagsAny, value: "104"),
        ])
        #expect(store.state.filter.input.tag.selection.any == [inboxTag])
    }

    // Rows stay on screen while the live fetch runs: clearing them on every keystroke would flicker
    // the list into a spinner while typing.
    @Test
    func search_delegate_inboxQueryChanged_keepsRowsWhileFetching() async throws {
        let inboxTag = Tag.testValue(id: 104, name: "Inbox")

        let store = TestStore(initialState: DocumentListReducer.State.testValue(
            filter: .testValue(
                input: .testValue(tag: .init(rule: .any, selection: .init(any: [inboxTag]))),
                isInbox: true
            ),
            isLoaded: true,
            search: .testValue(isGlobalSearchEnabled: false)
        )) {
            DocumentListReducer()
        } withDependencies: {
            $0.getDocuments.execute = { _, _ in .testValue(count: 1, results: [.testValue()]) }
        }
        store.exhaustivity = .off

        let documentsBefore = store.state.documents

        await store.send(.search(.delegate(.inboxQueryChanged("inv"))))

        #expect(store.state.documents == documentsBefore)

        await store.receive(\.replaceDocuments)
        await store.receive(\.binding, .set(\.isLoaded, true))
    }

    // Submit flushes after the live path has already applied the same query.
    @Test
    func search_delegate_inboxQueryChanged_ignoresDuplicates() async throws {
        let store = TestStore(initialState: DocumentListReducer.State.testValue(
            filter: .testValue(
                input: .testValue(searchType: .titleContent, searchValue: "inv"),
                isInbox: true
            ),
            search: .testValue(isGlobalSearchEnabled: false)
        )) {
            DocumentListReducer()
        } withDependencies: {
            $0.getDocuments.execute = { _, _ in
                Issue.record("a duplicate query must not refetch")
                return .testValue()
            }
        }

        await store.send(.search(.delegate(.inboxQueryChanged("inv"))))
    }

    @Test
    func search_delegate_inboxQueryChanged_ignoredWhenNotInbox() async throws {
        let store = TestStore(initialState: DocumentListReducer.State.testValue(
            search: .testValue(isGlobalSearchEnabled: false)
        )) {
            DocumentListReducer()
        } withDependencies: {
            $0.getDocuments.execute = { _, _ in
                Issue.record("a non-inbox list must not fetch for an inbox query")
                return .testValue()
            }
        }

        await store.send(.search(.delegate(.inboxQueryChanged("inv"))))

        #expect(store.state.filter.input.searchValue.isEmpty)
    }

    // Refreshing with text in the bar refetches the filtered inbox rather than dropping the query
    // while the bar still shows it.
    @Test
    func view_onRefresh_preservesTheInboxQuery() async throws {
        let server = Server.testValue()

        @Shared(.inboxTags(server))
        var inboxTags: [ApiInterface.Tag.Id] = [104]

        @Shared(.tags(server))
        var tags: IdentifiedArrayOf<ApiInterface.Tag> = [
            .testValue(id: 104, isInboxTag: true, name: "Inbox")
        ]

        let filterRulesUsed = LockIsolated<[FilterRule]?>(nil)

        var staleInboxFilter = DocumentFilter()
        staleInboxFilter.isInbox = true
        staleInboxFilter.input.searchType = .titleContent
        staleInboxFilter.input.searchValue = "inv"

        let store = TestStore(initialState: DocumentListReducer.State.testValue(
            filter: staleInboxFilter,
            search: .testValue(isGlobalSearchEnabled: false, searchText: "inv"),
            server: server
        )) {
            DocumentListReducer()
        } withDependencies: {
            $0.getDocuments.execute = { input, _ in
                filterRulesUsed.setValue(input.filterRules)
                return .testValue(count: 1, results: [.testValue()])
            }
        }
        store.exhaustivity = .off

        await store.send(.view(.onRefresh))

        #expect(store.state.filter.input.searchValue == "inv")

        await store.receive(\.replaceDocuments)
        await store.receive(\.binding, .set(\.isLoaded, true))

        #expect(filterRulesUsed.value == [
            .init(ruleType: .titleContent, value: "inv"),
            .init(ruleType: .hasTagsAny, value: "104"),
        ])
    }

    // Typing through to the fetch, end to end: debounce, delegate, combined rules. `globalSearch`
    // is deliberately left unimplemented — reaching it fails the test.
    @Test
    func search_searchTextChanged_fetchesInboxPlusQuery() async throws {
        let clock = TestClock()
        let inboxTag = Tag.testValue(id: 104, name: "Inbox")
        let filterRulesUsed = LockIsolated<[FilterRule]?>(nil)

        let store = TestStore(initialState: DocumentListReducer.State.testValue(
            filter: .testValue(
                input: .testValue(tag: .init(rule: .any, selection: .init(any: [inboxTag]))),
                isInbox: true
            ),
            search: .testValue(isGlobalSearchEnabled: false)
        )) {
            DocumentListReducer()
        } withDependencies: {
            $0.continuousClock = clock
            $0.getDocuments.execute = { input, _ in
                filterRulesUsed.setValue(input.filterRules)
                return .testValue(count: 1, results: [.testValue()])
            }
        }
        store.exhaustivity = .off

        await store.send(.search(.view(.searchTextChanged("i")))) {
            $0.search.searchText = "i"
        }

        await clock.advance(by: .milliseconds(400))
        await store.receive(\.search.searchDebounced)
        await store.receive(\.search.delegate.inboxQueryChanged, "i")
        await store.receive(\.replaceDocuments)
        await store.receive(\.binding, .set(\.isLoaded, true))

        #expect(store.state.filter.input.searchValue == "i")
        #expect(filterRulesUsed.value == [
            .init(ruleType: .titleContent, value: "i"),
            .init(ruleType: .hasTagsAny, value: "104"),
        ])
    }
}
