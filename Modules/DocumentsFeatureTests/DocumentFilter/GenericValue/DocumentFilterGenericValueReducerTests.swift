@testable import DocumentsFeature

import ApiInterface
import Components
import ComposableArchitecture
import Foundation
import Testing
import TestSupport

@MainActor
@Suite(
    .dependencies()
)
struct DocumentFilterGenericValueListReducerTests {

    @Test
    func test_filteredValues() async throws {
        let store = TestStore(initialState: .testValue(
            searchText: "Off",
            values: [
                .testValue(id: 1, name: "Bank"),
                .testValue(id: 2, name: "Tax Office"),
            ]
        )) {
            DocumentFilterGenericValueListReducer<Correspondent>()
        }

        #expect(store.state.filteredValues == [.testValue(id: 2, name: "Tax Office")])
    }

    @Test
    func test_binding_rule() async throws {
        let store = TestStore(initialState: .testValue()) {
            DocumentFilterGenericValueListReducer<Correspondent>()
        }

        await store.send(.binding(.set(\.rule, .exclude))) {
            $0.rule = .exclude
        }
        await store.receive(.delegate(.filterUpdated(
            rule: .exclude,
            selection: []
        )))
    }

    @Test
    func test_view_closeButtonTapped() async throws {
        var isDismissed = false
        let store = TestStore(initialState: .testValue()) {
            DocumentFilterGenericValueListReducer<Correspondent>()
        } withDependencies: {
            $0.dismiss = .init { isDismissed = true }
        }

        await store.send(.view(.closeButtonTapped))
        #expect(isDismissed == true)
    }

    @Test
    func test_view_valueTapped() async throws {
        let store = TestStore(initialState: .testValue()) {
            DocumentFilterGenericValueListReducer<Correspondent>()
        }

        await store.send(.view(.valueTapped(.testValue()))) {
            $0.selection = [.testValue()]
        }
        await store.receive(.delegate(.filterUpdated(
            rule: .include,
            selection: [.testValue()]
        )))
        await store.send(.view(.valueTapped(.testValue()))) {
            $0.selection = []
        }
        await store.receive(.delegate(.filterUpdated(
            rule: .include,
            selection: []
        )))
    }
}
