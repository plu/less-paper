@testable import ServersFeature

import ApiInterface
import ComposableArchitecture
import Foundation
import Testing
import TestSupport

@MainActor
@Suite(
    .dependencies()
)
struct ServerDetailReducerTests {

    @Test
    func onAppearRefreshesAndKeepsTheStatistics() async {
        let store = TestStore(initialState: ServerDetailReducer.State(server: .testValue())) {
            ServerDetailReducer()
        } withDependencies: {
            $0.updateCache.execute = { _ in }
            $0.getStatistics.execute = { _ in .testValue() }
            $0.authenticationProvider.getToken = { _ in "c0ff33" }
        }

        await store.send(.view(.onAppear)) {
            $0.isRefreshing = true
        }
        await store.receive(\.statisticsLoaded) {
            $0.statistics = .testValue()
            $0.isRefreshing = false
        }
        await store.receive(\.authModeLoaded) {
            $0.hasToken = true
        }
    }

    // onAppear also loads the auth mode, independently of the cache refresh - a server with no
    // token (remote-user mode) must still resolve, even though it has nothing to do with
    // statistics or the cache.
    @Test
    func onAppearLoadsRemoteUserModeWhenThereIsNoToken() async {
        let store = TestStore(initialState: ServerDetailReducer.State(server: .testValue())) {
            ServerDetailReducer()
        } withDependencies: {
            $0.updateCache.execute = { _ in }
            $0.getStatistics.execute = { _ in .testValue() }
            $0.authenticationProvider.getToken = { _ in nil }
        }

        await store.send(.view(.onAppear)) {
            $0.isRefreshing = true
        }
        await store.receive(\.statisticsLoaded) {
            $0.statistics = .testValue()
            $0.isRefreshing = false
        }
        await store.receive(\.authModeLoaded) {
            $0.hasToken = false
        }
    }

    // The decision this test defends: a failed refresh must cost nothing. The screen keeps the last
    // known numbers rather than emptying or replacing itself.
    @Test
    func aFailedRefreshKeepsTheCachedValues() async {
        let server = Server.testValue()

        @Shared(.tags(server)) var tags: IdentifiedArrayOf<ApiInterface.Tag>
        $tags.withLock { $0 = [.testValue()] }

        let store = TestStore(initialState: ServerDetailReducer.State(server: server)) {
            ServerDetailReducer()
        } withDependencies: {
            $0.updateCache.execute = { _ in throw TestError.someError }
        }

        await store.send(.view(.onAppear)) {
            $0.isRefreshing = true
        }
        await store.receive(\.refreshFailed) {
            $0.isRefreshing = false
            $0.refreshFailed = true
        }
        // Concatenated after the failed refresh, and unaffected by it - the two effects have
        // nothing to do with each other.
        await store.receive(\.authModeLoaded) {
            $0.hasToken = true
        }

        #expect(store.state.tags.count == 1)
    }
}
