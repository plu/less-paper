@testable import DocumentsFeature

import ComposableArchitecture
import Foundation
import Testing
import TestSupport

@MainActor
@Suite(
    .dependencies()
)
struct DocumentFilterSearchValueBindingTests {

    @Test
    func test_searchValueBinding_sendsWhenTheValueChanges() async throws {
        let (view, sent) = view(searchValue: "Leg")

        view.searchValueBinding.wrappedValue = "Lego"

        #expect(sent.value == ["Lego"])
    }

    // SwiftUI writes the binding one last time as the sheet tears down, with the value it already
    // holds. By then the presentation state is gone, so the action lands on an absent destination
    // and ComposableArchitecture reports a runtime issue. Nothing is lost by dropping it: the value
    // is unchanged.
    @Test
    func test_searchValueBinding_ignoresRedundantWrites() async throws {
        let (view, sent) = view(searchValue: "Lego")

        view.searchValueBinding.wrappedValue = "Lego"

        #expect(sent.value.isEmpty)
    }

    // The same redundant write happens on presentation, where it cost a pointless debounce rather
    // than a runtime issue.
    @Test
    func test_searchValueBinding_ignoresTheEmptyWriteOnAppear() async throws {
        let (view, sent) = view(searchValue: "")

        view.searchValueBinding.wrappedValue = ""

        #expect(sent.value.isEmpty)
    }

    private func view(searchValue: String) -> (DocumentFilterView, LockIsolated<[String]>) {
        let sent = LockIsolated<[String]>([])
        let store = Store(
            initialState: DocumentFilterReducer.State.testValue(
                input: .testValue(searchValue: searchValue)
            )
        ) {
            Reduce<DocumentFilterReducer.State, DocumentFilterReducer.Action> { _, action in
                if case let .view(.searchValueChanged(value)) = action {
                    sent.withValue { $0.append(value) }
                }
                return .none
            }
        }
        return (DocumentFilterView(store: store), sent)
    }
}
