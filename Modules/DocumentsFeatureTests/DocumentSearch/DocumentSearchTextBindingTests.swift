@testable import DocumentsFeature

import ComposableArchitecture
import Foundation
import Testing
import TestSupport

@MainActor
@Suite(
    .testDependencies()
)
struct DocumentSearchTextBindingTests {

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

    private func view(searchText: String) -> (DocumentListView, LockIsolated<[String]>) {
        let sent = LockIsolated<[String]>([])
        let store = Store(
            initialState: DocumentListReducer.State.testValue(
                search: .testValue(searchText: searchText)
            )
        ) {
            Reduce<DocumentListReducer.State, DocumentListReducer.Action> { _, action in
                if case let .search(.view(.searchTextChanged(value))) = action {
                    sent.withValue { $0.append(value) }
                }
                return .none
            }
        }
        return (DocumentListView(store: store), sent)
    }
}
