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
struct DocumentListSearchSheetTests {

    @Test
    func view_searchButtonTapped_presentsTheSheet() async throws {
        let store = TestStore(initialState: DocumentListReducer.State.testValue()) {
            DocumentListReducer()
        }

        await store.send(.view(.searchButtonTapped)) {
            $0.isSearchPresented = true
        }
    }

    @Test
    func search_delegate_documentTapped_dismissesTheSheet() async throws {
        let store = TestStore(initialState: DocumentListReducer.State.testValue(
            isSearchPresented: true
        )) {
            DocumentListReducer()
        }
        store.exhaustivity = .off

        await store.send(.search(.delegate(.documentTapped(Document.Id(rawValue: 1))))) {
            $0.isSearchPresented = false
        }
        await store.receive(\.openDocument)
    }

    @Test
    func search_delegate_filterRequested_dismissesTheSheet() async throws {
        let tag = Tag.testValue(id: 7, name: "Manual")
        let store = TestStore(initialState: DocumentListReducer.State.testValue(
            isSearchPresented: true
        )) {
            DocumentListReducer()
        } withDependencies: {
            $0.getDocuments.execute = { _, _ in .testValue() }
        }
        store.exhaustivity = .off

        await store.send(.search(.delegate(.filterRequested(.searchResult(tag: tag))))) {
            $0.isSearchPresented = false
        }
    }

    @Test
    func search_delegate_queryCommitted_dismissesTheSheet() async throws {
        let store = TestStore(initialState: DocumentListReducer.State.testValue(
            isSearchPresented: true
        )) {
            DocumentListReducer()
        } withDependencies: {
            $0.getDocuments.execute = { _, _ in .testValue() }
        }
        store.exhaustivity = .off

        await store.send(.search(.delegate(.queryCommitted("manual")))) {
            $0.isSearchPresented = false
        }
    }

    @Test
    func search_delegate_savedViewTapped_dismissesTheSheet() async throws {
        let savedView = SavedView.testValue()
        let store = TestStore(initialState: DocumentListReducer.State.testValue(
            isSearchPresented: true
        )) {
            DocumentListReducer()
        } withDependencies: {
            $0.getDocuments.execute = { _, _ in .testValue() }
        }
        store.exhaustivity = .off

        await store.send(.search(.delegate(.savedViewTapped(savedView)))) {
            $0.isSearchPresented = false
        }
    }

    // The reason `search` stays a plain child with a `Scope` instead of moving into `destination`:
    // dismissing the sheet must not take the query and its results with it.
    @Test
    func closingAndReopeningTheSheet_keepsTheQueryAndResults() async throws {
        let results = GlobalSearchOutput.testValue(tags: [.testValue(id: 7, name: "Manual")])
        let store = TestStore(initialState: DocumentListReducer.State.testValue(
            isSearchPresented: true,
            search: .testValue(results: results, searchText: "manual")
        )) {
            DocumentListReducer()
        } withDependencies: {
            $0.globalSearch.execute = { _, _ in
                Issue.record("reopening the sheet must not refetch")
                return .testValue()
            }
        }

        await store.send(.binding(.set(\.isSearchPresented, false))) {
            $0.isSearchPresented = false
        }
        await store.send(.view(.searchButtonTapped)) {
            $0.isSearchPresented = true
        }

        #expect(store.state.search.searchText == "manual")
        #expect(store.state.search.results == results)
    }
}
