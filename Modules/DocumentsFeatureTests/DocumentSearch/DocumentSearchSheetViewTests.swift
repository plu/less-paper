@testable import DocumentsFeature

import ComposableArchitecture
import Foundation
import Testing
import TestSupport

@MainActor
@Suite(
    .testDependencies()
)
struct DocumentSearchSheetViewTests {

    @Test
    func searchTextBinding_sendsWhenTheValueChanges() async throws {
        let (view, sent) = view(searchText: "ma")

        view.searchTextBinding.wrappedValue = "man"

        #expect(sent.value == ["man"])
    }

    // SwiftUI writes the binding with the value it already holds, both when the field appears and
    // when it tears down. Each redundant write would otherwise cost a 400ms debounce and a request
    // for a search that had not changed.
    @Test
    func searchTextBinding_ignoresRedundantWrites() async throws {
        let (view, sent) = view(searchText: "man")

        view.searchTextBinding.wrappedValue = "man"

        #expect(sent.value.isEmpty)
    }

    @Test
    func searchTextBinding_ignoresTheEmptyWriteOnAppear() async throws {
        let (view, sent) = view(searchText: "")

        view.searchTextBinding.wrappedValue = ""

        #expect(sent.value.isEmpty)
    }

    // Reopening the sheet hands the same child store back, so the field comes up holding the query
    // it was closed on rather than an empty string.
    @Test
    func searchTextBinding_readsTheStoredQuery() async throws {
        let (view, _) = view(searchText: "manual")

        #expect(view.searchTextBinding.wrappedValue == "manual")
    }

    private func view(searchText: String) -> (DocumentSearchSheetView, LockIsolated<[String]>) {
        let sent = LockIsolated<[String]>([])
        let store = Store(
            initialState: DocumentSearchReducer.State.testValue(searchText: searchText)
        ) {
            Reduce<DocumentSearchReducer.State, DocumentSearchReducer.Action> { _, action in
                if case let .view(.searchTextChanged(value)) = action {
                    sent.withValue { $0.append(value) }
                }
                return .none
            }
        }
        return (DocumentSearchSheetView(store: store), sent)
    }
}
