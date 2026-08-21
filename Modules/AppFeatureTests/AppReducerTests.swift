@testable import AppFeature

import ApiInterface
import ComposableArchitecture
import Foundation
import IdentifiedCollections
import ServersFeature
import SettingsFeature
import SwiftSharing
import Testing
import TestSupport

@MainActor
@Suite(
    .dependencies()
)
struct AppReducerTests {

    @Test
    func test_didBecomeActive_refreshesStatistics() async {
        let serversReceived = LockIsolated<[Server]>([])
        let server = Server.testValue()

        let store = TestStore(
            initialState: AppReducer.State(main: MainReducer.State(server: server)),
            reducer: { AppReducer() },
            withDependencies: {
                $0.getStatistics.execute = { server in
                    serversReceived.withValue { $0.append(server) }
                    return .testValue()
                }
            }
        )

        await store.send(.didBecomeActive)
        await store.finish()

        #expect(serversReceived.value == [server])
    }

    @Test
    func test_didBecomeActive_withoutServer_doesNothing() async {
        let store = TestStore(
            initialState: AppReducer.State(),
            reducer: { AppReducer() }
        )

        await store.send(.didBecomeActive)
    }

    @Test
    func test_bootstrap() async {
        let updateCacheServer = LockIsolated<Server?>(nil)
        let server1 = Server.testValue(alias: "Server 1", id: "1")
        let server2 = Server.testValue(alias: "Server 2", id: "2")

        @Shared(.selectedServer)
        var selectedServer: Server? = server1

        let store = TestStore(
            initialState: AppReducer.State(),
            reducer: { AppReducer() },
            withDependencies: {
                $0.updateCache.execute = { updateCacheServer.setValue($0) }
            }
        )
        let bootstrap = await store.send(.bootstrap)

        await store.receive(\.selectedServerChanged, server1) {
            $0.main = MainReducer.State(server: server1)
        }

        await store.receive(\.certificateApproval.bootstrap)

        #expect(updateCacheServer.value == server1)

        $selectedServer.withLock { $0 = server2 }

        await store.receive(\.selectedServerChanged, server2) {
            $0.main = MainReducer.State(server: server2)
        }

        #expect(updateCacheServer.value == server2)

        $selectedServer.withLock { $0 = nil }

        await store.receive(\.selectedServerChanged, nil) {
            $0.main = nil
        }

        await bootstrap.cancel()
    }

    // Selecting a different server writes @Shared(.selectedServer), which makes this reducer
    // rebuild MainReducer.State from scratch — emptying the settings navigation stack that the
    // tapped row lives in. Anything the select effect sends after that write lands on a row the
    // rebuild has already destroyed, and forEach reports a missing element.
    @Test
    func test_selectingADifferentServerFromSettings_doesNotSendToADestroyedRow() async {
        let server1 = Server.testValue(alias: "Server 1", id: "1")
        let server2 = Server.testValue(alias: "Server 2", id: "2")

        @Shared(.servers)
        var servers: IdentifiedArrayOf<Server> = [server1, server2]

        @Shared(.selectedServer)
        var selectedServer: Server? = server1

        let store = TestStore(
            initialState: AppReducer.State(main: MainReducer.State(server: server1)),
            reducer: { AppReducer() },
            withDependencies: {
                $0.updateCache.execute = { _ in }
            }
        )
        store.exhaustivity = .off

        let bootstrap = await store.send(.bootstrap)

        await store.send(.main(.settingList(.path(.push(
            id: 0,
            state: .serverList(ServerListReducer.State())
        )))))

        await store.send(.main(.settingList(.path(.element(
            id: 0,
            action: .serverList(.servers(.element(
                id: server2.id,
                action: .view(.serverTapped)
            )))
        )))))

        await store.finish()

        #expect(selectedServer == server2)

        await bootstrap.cancel()
    }
}
