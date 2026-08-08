@testable import ServersFeature

import ApiInterface
import ComposableArchitecture
import SwiftUI
import Testing
import TestSupport

@MainActor
@Suite(
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
        store.send(.bootstrap)

        try await Task.sleep(for: .milliseconds(1))

        assertSnapshot(
            of: NavigationStack {
                ServerListView(store: store)
            },
            as: .image(layout: .device(config: .iPhone12)),
            named: "withData"
        )
    }
}
