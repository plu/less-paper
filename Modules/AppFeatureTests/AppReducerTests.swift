@testable import AppFeature

import ApiInterface
import ComposableArchitecture
import Foundation
import IdentifiedCollections
import ImageFeature
import Logging
import ServersFeature
import SettingsFeature
import SwiftSharing
import Testing
import TestSupport
import TipsFeature
import UIKit

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
    func test_didBecomeActive_refreshesFavorites() async {
        let refreshed = LockIsolated(false)

        let store = TestStore(initialState: AppReducer.State(main: .testValue())) {
            AppReducer()
        } withDependencies: {
            $0.refreshFavorites.execute = { force, _ in
                #expect(force == false)
                refreshed.setValue(true)
                return FavoriteRefreshResult()
            }
        }

        await store.send(.didBecomeActive)
        await store.finish()

        #expect(refreshed.value)
    }

    @Test
    func test_didBecomeActive_refreshesPermissions() async {
        let serversReceived = LockIsolated<[Server]>([])
        let server = Server.testValue()

        let store = TestStore(
            initialState: AppReducer.State(main: MainReducer.State(server: server)),
            reducer: { AppReducer() },
            withDependencies: {
                $0.getCurrentUser.execute = { server in
                    serversReceived.withValue { $0.append(server) }
                    return .testValue()
                }
            }
        )
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.didBecomeActive)
        await store.finish()

        #expect(serversReceived.value == [server])
    }

    // A transient failure must leave the last known permissions in place. Clearing them would swing
    // the whole UI on a dropped connection - to ungated with nil, or fully gated with [].
    @Test
    func test_didBecomeActive_keepsCachedPermissionsWhenTheRefreshFails() async {
        let server = Server.testValue()

        @Shared(.permissions(server))
        var permissions: [Permission]?
        $permissions.withLock { $0 = [.viewDocument] }

        let store = TestStore(
            initialState: AppReducer.State(main: MainReducer.State(server: server)),
            reducer: { AppReducer() },
            withDependencies: {
                $0.getCurrentUser.execute = { _ in throw ApiError(errors: ["nope"]) }
            }
        )
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.didBecomeActive)
        await store.finish()

        #expect(permissions == [.viewDocument])
    }

    // Backgrounding and foregrounding repeatedly must not stack refreshes: each one re-downloads
    // the same PDFs and holds them whole in memory. Newest wins, so the second trigger runs and the
    // first is cancelled where it stands.
    @Test
    func test_didBecomeActive_doesNotStackRefreshes() async {
        let clock = TestClock()
        let completed = LockIsolated(0)

        let store = TestStore(initialState: AppReducer.State(main: .testValue())) {
            AppReducer()
        } withDependencies: {
            $0.continuousClock = clock
            $0.refreshFavorites.execute = { _, _ in
                try await clock.sleep(for: .seconds(1))
                completed.withValue { $0 += 1 }
                return FavoriteRefreshResult()
            }
        }

        await store.send(.didBecomeActive)
        await store.send(.didBecomeActive)
        await clock.advance(by: .seconds(1))
        await store.finish()

        #expect(completed.value == 1)
    }

    // The automatic path is silent: a failure must not surface anything.
    @Test
    func test_didBecomeActive_swallowsARefreshFailure() async {
        let store = TestStore(initialState: AppReducer.State(main: .testValue())) {
            AppReducer()
        } withDependencies: {
            $0.refreshFavorites.execute = { _, _ in throw ApiError.testValue() }
        }

        await store.send(.didBecomeActive)
        await store.finish()
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
    func test_lifecyclePhaseChanged_logsTheTransition() async {
        let messages = LockIsolated<[String]>([])

        let store = TestStore(
            initialState: AppReducer.State(),
            reducer: { AppReducer() },
            withDependencies: {
                $0.log.record = { message, _, _ in
                    messages.withValue { $0.append(message) }
                }
            }
        )
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.lifecyclePhaseChanged(.background))
        await store.send(.lifecyclePhaseChanged(.active))

        #expect(messages.value == ["scene phase: background", "scene phase: active"])
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
                // Unrelated to this test, but bootstrap now also starts the tip observer, and an
                // unstubbed TipJar.updates reports an "Unimplemented" issue the moment it is called.
                $0.tipJar.updates = { AsyncStream { $0.finish() } }
            }
        )
        let bootstrap = await store.send(.bootstrap)

        await store.receive(\.logLaunchContext)

        await store.receive(\.selectedServerChanged, server1) {
            $0.main = MainReducer.State(server: server1)
        }

        await store.receive(\.certificateApproval.bootstrap)

        await store.receive(\.forwardAuth.bootstrap)

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

    // .bootstrap merges runSelectedServerObserver() and runTipObserver(), both never-ending
    // observation effects, so this sends .logLaunchContext directly rather than .bootstrap and
    // awaiting store.finish() - which would hang forever waiting on those.
    @Test
    func test_bootstrap_logsTheLaunchContext() async {
        let messages = LockIsolated<[String]>([])

        let store = TestStore(
            initialState: AppReducer.State(),
            reducer: { AppReducer() },
            withDependencies: {
                $0.log.record = { message, _, _ in
                    messages.withValue { $0.append(message) }
                }
                $0.deviceContext = .testValue
                $0.imageCacheUsage.read = { StorageUsage(bytes: 42_100_000, fileCount: 318) }
                $0.storageUsage.measure = { _ in StorageUsage(bytes: 1_200_000, fileCount: 14) }
            }
        )
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.logLaunchContext)
        await store.finish()

        #expect(messages.value.contains("LessPaper 1.0.0 (1) · iOS 26.0 · iPhone17,2 · en_US · debug"))
    }

    @Test
    func test_bootstrap_logsCacheSizes() async {
        let messages = LockIsolated<[String]>([])

        let store = TestStore(
            initialState: AppReducer.State(),
            reducer: { AppReducer() },
            withDependencies: {
                $0.log.record = { message, _, _ in
                    messages.withValue { $0.append(message) }
                }
                $0.imageCacheUsage.read = { StorageUsage(bytes: 42_100_000, fileCount: 318) }
                $0.storageUsage.measure = { _ in StorageUsage(bytes: 1_200_000, fileCount: 14) }
            }
        )
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.logLaunchContext)
        await store.finish()

        #expect(messages.value.contains { $0.hasPrefix("caches: images 42.1 MB / 318 files · app group ") })
    }

    // The two tests above cover runLogLaunchContext() in isolation, so this only confirms
    // .bootstrap really does trigger it. It never awaits store.finish(): .bootstrap also merges
    // the never-ending selected-server and tip observers, and finish() would wait on those forever.
    @Test
    func test_bootstrap_sendsLogLaunchContext() async {
        let store = TestStore(
            initialState: AppReducer.State(),
            reducer: { AppReducer() },
            withDependencies: {
                // bootstrap also starts the tip observer, and an unstubbed TipJar.updates reports
                // an "Unimplemented" issue the moment it is called.
                $0.tipJar.updates = { AsyncStream { $0.finish() } }
            }
        )
        store.exhaustivity = .off(showSkippedAssertions: false)

        let bootstrap = await store.send(.bootstrap)

        await store.receive(\.logLaunchContext)

        await bootstrap.cancel()
    }

    // The memory warning line only exists for the crash-adjacent case nobody is watching, which is
    // exactly why it needs a test: if the observer stopped being started, nothing would ever say so.
    //
    // The notification is posted in a loop because nothing signals when the effect's AsyncSequence
    // has begun observing, and a post that lands before it does is not delivered to anyone. Posting
    // again is harmless - the assertion is that the line appears, not how many times. And the
    // bootstrap task is cancelled rather than finished: .bootstrap merges never-ending observers,
    // so store.finish() would wait on them forever.
    @Test
    func test_bootstrap_logsAMemoryWarning() async {
        let messages = LockIsolated<[String]>([])

        let store = TestStore(
            initialState: AppReducer.State(),
            reducer: { AppReducer() },
            withDependencies: {
                $0.log.record = { message, _, _ in
                    messages.withValue { $0.append(message) }
                }
                $0.deviceContext = .testValue
                $0.imageCacheUsage.read = { .zero }
                $0.storageUsage.measure = { _ in .zero }
                $0.tipJar.updates = { AsyncStream { $0.finish() } }
            }
        )
        store.exhaustivity = .off(showSkippedAssertions: false)

        let bootstrap = await store.send(.bootstrap)

        for _ in 1 ... 200 where !messages.value.contains("memory warning") {
            NotificationCenter.default.post(
                name: UIApplication.didReceiveMemoryWarningNotification,
                object: nil
            )
            try? await Task.sleep(for: .milliseconds(5))
        }

        await bootstrap.cancel()

        #expect(messages.value.contains("memory warning"))
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
                $0.tipJar.updates = { AsyncStream { $0.finish() } }
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
