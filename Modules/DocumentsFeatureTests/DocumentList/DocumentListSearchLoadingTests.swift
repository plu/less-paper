@testable import DocumentsFeature

import ApiInterface
import ComposableArchitecture
import Foundation
import Testing
import TestSupport

// Covers `clearForPendingFetch()`: while a search-applied filter is refetching, the previous rows
// must not linger on screen looking current. `DocumentListEmptyView` already renders empty rows
// with `isLoaded == false` as a spinner, so clearing both together is what puts it on screen.
@MainActor
@Suite(
    .testDependencies()
)
struct DocumentListSearchLoadingTests {

    @Test
    func search_delegate_filterRequested_clearsRowsAndShowsSpinner() async throws {
        let tag = Tag.testValue(id: 7, name: "Manual")
        let store = TestStore(initialState: DocumentListReducer.State.testValue(
            isLoaded: true,
            nextPage: .testValue()
        )) {
            DocumentListReducer()
        } withDependencies: {
            $0.getDocuments.execute = { _, _ in .testValue() }
        }
        store.exhaustivity = .off

        await store.send(.search(.delegate(.filterRequested(.searchResult(tag: tag))))) {
            $0.error = nil
            $0.filter.input = .searchResult(tag: tag)
            $0.filter.savedView = nil
            $0.documents = []
            $0.documentSelection.allLoadedDocuments = []
            $0.isLoaded = false
            $0.nextPage = nil
            $0.totalNumberOfDocuments = 0
        }
    }

    @Test
    func search_delegate_queryCommitted_clearsRowsAndShowsSpinner() async throws {
        let store = TestStore(initialState: DocumentListReducer.State.testValue(
            isLoaded: true,
            nextPage: .testValue()
        )) {
            DocumentListReducer()
        } withDependencies: {
            $0.getDocuments.execute = { _, _ in .testValue() }
        }
        store.exhaustivity = .off

        await store.send(.search(.delegate(.queryCommitted("manual")))) {
            $0.error = nil
            $0.filter.input.searchType = .titleContent
            $0.filter.input.searchValue = "manual"
            $0.documents = []
            $0.documentSelection.allLoadedDocuments = []
            $0.isLoaded = false
            $0.nextPage = nil
            $0.totalNumberOfDocuments = 0
        }
    }

    @Test
    func search_delegate_savedViewTapped_clearsRowsAndShowsSpinner() async throws {
        let savedView = SavedView.testValue(
            filterRules: [.init(ruleType: .titleContent, value: "Lego")]
        )
        let store = TestStore(initialState: DocumentListReducer.State.testValue(
            filter: .testValue(
                input: .testValue(searchValue: "Invoice"),
                savedView: nil
            ),
            isLoaded: true,
            nextPage: .testValue()
        )) {
            DocumentListReducer()
        } withDependencies: {
            $0.getDocuments.execute = { _, _ in .testValue() }
        }
        store.exhaustivity = .off

        await store.send(.search(.delegate(.savedViewTapped(savedView)))) {
            $0.documents = []
            $0.documentSelection.allLoadedDocuments = []
            $0.isLoaded = false
            $0.nextPage = nil
            $0.totalNumberOfDocuments = 0
        }
        await store.receive(\.view) {
            $0.error = nil
            $0.filter.input = .testValue(searchValue: "Lego")
            $0.filter.savedView = savedView
        }
    }

    // Confirms the consequence this change accepts: a failed search-applied filter used to leave
    // the old rows on screen plus a toast; now the rows are already gone, so the failure lands on
    // DocumentListEmptyView's error state (documents empty, isLoaded true, error set - that
    // combination is what draws the Reload button rather than "No matching documents").
    @Test
    func search_delegate_filterRequested_whenFetchFails_landsOnTheErrorState() async throws {
        let tag = Tag.testValue(id: 7, name: "Manual")
        let store = TestStore(initialState: DocumentListReducer.State.testValue(
            isLoaded: true
        )) {
            DocumentListReducer()
        } withDependencies: {
            $0.getDocuments.execute = { _, _ in throw ApiError.testValue() }
            $0.toastPresenter.present = { _ in }
        }
        store.exhaustivity = .off

        await store.send(.search(.delegate(.filterRequested(.searchResult(tag: tag)))))
        await store.receive(\.error)
        await store.receive(\.binding, .set(\.isLoaded, true))

        #expect(store.state.documents.isEmpty)
        #expect(store.state.isLoaded)
        #expect(store.state.error != nil)
    }

    // The regression this guards against: opening a document is instant, so clearing the rows
    // first would flash the spinner for no reason.
    @Test
    func search_delegate_documentTapped_doesNotClearRows() async throws {
        let store = TestStore(initialState: DocumentListReducer.State.testValue(
            isLoaded: true
        )) {
            DocumentListReducer()
        }
        store.exhaustivity = .off

        let documentsBefore = store.state.documents

        await store.send(.search(.delegate(.documentTapped(Document.Id(rawValue: 1)))))
        await store.receive(\.openDocument)

        #expect(store.state.documents == documentsBefore)
        #expect(store.state.isLoaded == true)
    }

    // A non-search refetch: its current behaviour (reset the filter, keep the rows on screen while
    // it refetches) is deliberate and must stay exactly as it is.
    @Test
    func view_allDocumentsButtonTapped_doesNotClearRows() async throws {
        let store = TestStore(initialState: DocumentListReducer.State.testValue(
            isLoaded: true
        )) {
            DocumentListReducer()
        } withDependencies: {
            $0.getDocuments.execute = { _, _ in .testValue() }
        }
        store.exhaustivity = .off

        let documentsBefore = store.state.documents

        await store.send(.view(.allDocumentsButtonTapped)) {
            $0.error = nil
            $0.filter = .init()
            $0.search = DocumentSearchReducer.State(server: $0.server)
        }

        #expect(store.state.documents == documentsBefore)
        #expect(store.state.isLoaded == true)
    }
}
