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
struct DocumentFilterTagListReducerTests {

    @Test
    func test_filteredValues() async throws {
        let store = TestStore(initialState: .testValue(
            searchText: "Do",
            values: [
                .testValue(id: 1, name: "Inbox"),
                .testValue(id: 2, name: "ToDo"),
            ]
        )) {
            DocumentFilterTagListReducer()
        }

        #expect(store.state.filteredValues == [.testValue(id: 2, name: "ToDo")])
    }

    @Test
    func test_binding_rule() async throws {
        let store = TestStore(initialState: .testValue()) {
            DocumentFilterTagListReducer()
        }

        await store.send(.binding(.set(\.rule, .any))) {
            $0.rule = .any
        }
        await store.receive(.delegate(.filterUpdated(
            rule: .any,
            selection: .testValue()
        )))
    }

    @Test
    func test_view_closeButtonTapped() async throws {
        var isDismissed = false
        let store = TestStore(initialState: .testValue()) {
            DocumentFilterTagListReducer()
        } withDependencies: {
            $0.dismiss = .init { isDismissed = true }
        }

        await store.send(.view(.closeButtonTapped))
        #expect(isDismissed == true)
    }

    @Test
    func test_view_valueTapped_all() async throws {
        let store = TestStore(initialState: .testValue(
            rule: .all,
            selection: .testValue(any: [.testValue(id: 1)]),
            values: IdentifiedArray(uniqueElements: (1 ... 5).map { Tag.testValue(id: $0) }),
        )) {
            DocumentFilterTagListReducer()
        }

        await store.send(.view(.valueTapped(.testValue(id: 1)))) {
            $0.selection = .testValue(
                all: .testValue(
                    exclude: [],
                    include: [.testValue(id: 1)]
                ),
                any: [.testValue(id: 1)]
            )
        }
        await store.receive(.delegate(.filterUpdated(
            rule: .all,
            selection: .testValue(
                all: .testValue(
                    exclude: [],
                    include: [.testValue(id: 1)]
                ),
                any: [.testValue(id: 1)]
            )
        )))
        await store.send(.view(.valueTapped(.testValue(id: 1)))) {
            $0.selection = .testValue(
                all: .testValue(
                    exclude: [.testValue(id: 1)],
                    include: []
                ),
                any: [.testValue(id: 1)]
            )
        }
        await store.receive(.delegate(.filterUpdated(
            rule: .all,
            selection: .testValue(
                all: .testValue(
                    exclude: [.testValue(id: 1)],
                    include: []
                ),
                any: [.testValue(id: 1)]
            )
        )))
        await store.send(.view(.valueTapped(.testValue(id: 1)))) {
            $0.selection = .testValue(
                all: .testValue(
                    exclude: [],
                    include: []
                ),
                any: [.testValue(id: 1)]
            )
        }
        await store.receive(.delegate(.filterUpdated(
            rule: .all,
            selection: .testValue(
                all: .testValue(
                    exclude: [],
                    include: []
                ),
                any: [.testValue(id: 1)]
            )
        )))
    }

    @Test
    func test_view_valueTapped_any() async throws {
        let store = TestStore(initialState: .testValue(
            rule: .any,
            selection: .testValue(
                all: .testValue(
                    exclude: [.testValue(id: 1)],
                    include: [.testValue(id: 1)]
                )
            )
        )) {
            DocumentFilterTagListReducer()
        }

        await store.send(.view(.valueTapped(.testValue(id: 1)))) {
            $0.selection = .testValue(
                all: .testValue(
                    exclude: [.testValue(id: 1)],
                    include: [.testValue(id: 1)]
                ),
                any: [.testValue(id: 1)]
            )
        }
        await store.receive(.delegate(.filterUpdated(
            rule: .any,
            selection: .testValue(
                all: .testValue(
                    exclude: [.testValue(id: 1)],
                    include: [.testValue(id: 1)]
                ),
                any: [.testValue(id: 1)]
            )
        )))
        await store.send(.view(.valueTapped(.testValue(id: 1)))) {
            $0.selection = .testValue(
                all: .testValue(
                    exclude: [.testValue(id: 1)],
                    include: [.testValue(id: 1)]
                ),
                any: []
            )
        }
        await store.receive(.delegate(.filterUpdated(
            rule: .any,
            selection: .testValue(
                all: .testValue(
                    exclude: [.testValue(id: 1)],
                    include: [.testValue(id: 1)]
                ),
                any: []
            )
        )))
    }
}
