@testable import ServersFeature

import ApiInterface
import ComposableArchitecture
import SwiftUI
import Testing
import TestSupport

@MainActor
@Suite(
    .dependencies(),
    .snapshots(record: .environment),
    .tags(.snapshotTests)
)
struct ServerListViewTests {

    @Test
    func testSnapshot_emptyState() async throws {
        assertSnapshot(
            of: NavigationStack {
                ServerListView(
                    store: Store(
                        initialState: .testValue(),
                        reducer: {
                            ServerListReducer()
                        }
                    )
                )
            },
            as: .image(layout: .device(config: .iPhone12))
        )
    }

    @Test
    func testSnapshot_withServers() async throws {
        @Shared(.selectedServer)
        var selectedServer = .testValue(alias: "TWO", id: "2", url: .testValue(string: "http://two"))

        @Shared(.servers)
        var servers: IdentifiedArrayOf<Server> = [
            .testValue(alias: "ONE", id: "1", url: .testValue(string: "http://one")),
            .testValue(alias: "TWO", id: "2", url: .testValue(string: "http://two")),
        ]

        let store = Store(
            initialState: .testValue(),
            reducer: {
                ServerListReducer()
            }
        )

        assertSnapshot(
            of: NavigationStack {
                ServerListView(store: store)
            },
            as: .image(layout: .device(config: .iPhone12)),
            named: "withData"
        )
    }

    // Dark mode: `m3SurfaceContainerLowest` and the default list row background are both white in
    // light mode, so a row that never sets `listRowBackground` only shows up against dark.
    @Test
    func testSnapshot_darkMode() async throws {
        @Shared(.selectedServer)
        var selectedServer = .testValue(alias: "TWO", id: "2", url: .testValue(string: "http://two"))

        @Shared(.servers)
        var servers: IdentifiedArrayOf<Server> = [
            .testValue(alias: "ONE", id: "1", url: .testValue(string: "http://one")),
            .testValue(alias: "TWO", id: "2", url: .testValue(string: "http://two")),
        ]

        let store = Store(
            initialState: .testValue(),
            reducer: {
                ServerListReducer()
            }
        )

        assertSnapshot(
            of: NavigationStack {
                ServerListView(store: store)
            },
            as: .image(
                layout: .device(config: .iPhone12),
                traits: .init(userInterfaceStyle: .dark)
            )
        )
    }

    @Test
    func test_init_doesNotSendActions() async throws {
        let actions = LockIsolated([String]())

        let store = Store(initialState: ServerListReducer.State.testValue()) {
            Reduce<ServerListReducer.State, ServerListReducer.Action> { _, action in
                let description = String(describing: action)
                actions.withValue { $0.append(description) }
                return .none
            }
            ServerListReducer()
        }

        _ = ServerListView(store: store)

        #expect(actions.value.isEmpty)
    }
}
