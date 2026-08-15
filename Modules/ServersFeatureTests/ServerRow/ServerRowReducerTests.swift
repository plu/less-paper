@testable import ServersFeature

import ApiInterface
import ComposableArchitecture
import Foundation
import SwiftSharing
import Testing

@MainActor
@Suite
struct ServerRowReducerTests {

    @Test
    func test_destination_confirmation_deleteButtonTapped() async throws {
        let store = TestStore(initialState: ServerRowReducer.State(
            destination: .confirmation(.confirmDelete(name: "dev")),
            server: .testValue()
        )) {
            ServerRowReducer()
        }

        await store.send(.destination(.presented(.confirmation(.deleteButtonTapped)))) {
            $0.destination = nil
        }
        await store.receive(\.delegate, .deleteServer)
    }

    @Test
    func test_view_deleteButtonTapped() async throws {
        let server = Server.testValue()
        let store = TestStore(initialState: ServerRowReducer.State(
            server: server
        )) {
            ServerRowReducer()
        }

        await store.send(.view(.deleteButtonTapped)) {
            $0.destination = .confirmation(.confirmDelete(name: server.alias))
        }
    }

    @Test
    func test_view_editButtonTapped() async throws {
        let store = TestStore(initialState: ServerRowReducer.State(
            server: .testValue()
        )) {
            ServerRowReducer()
        }

        await store.send(.view(.editButtonTapped))
        await store.receive(\.delegate, .editServer)
    }

    @Test
    func test_view_serverTapped_fillsCachesBeforeSelecting() async throws {
        let server = Server.testValue(alias: "Other", id: "other")
        let selectedDuringSync = LockIsolated<String?>("unset")

        @Shared(.selectedServer)
        var selectedServer: Server?

        let store = TestStore(initialState: ServerRowReducer.State(
            server: server
        )) {
            ServerRowReducer()
        } withDependencies: {
            $0.updateCache.execute = { _ in
                @Shared(.selectedServer)
                var current: Server?

                let id = current?.id
                selectedDuringSync.setValue(id)
            }
        }

        await store.send(.view(.serverTapped)) {
            $0.isSelecting = true
        }
        await store.receive(\.serverSelected) {
            $0.isSelecting = false
        }

        #expect(selectedDuringSync.value == nil, "must not be selected until its caches are filled")
        #expect(selectedServer == server)
    }

    /// Being offline must not leave the user stranded on the server list.
    @Test
    func test_view_serverTapped_selectsEvenWhenSyncFails() async throws {
        let server = Server.testValue(alias: "Other", id: "other")

        @Shared(.selectedServer)
        var selectedServer: Server?

        let store = TestStore(initialState: ServerRowReducer.State(
            server: server
        )) {
            ServerRowReducer()
        } withDependencies: {
            $0.updateCache.execute = { _ in throw ApiError.testValue() }
        }

        await store.send(.view(.serverTapped)) {
            $0.isSelecting = true
        }
        await store.receive(\.serverSelected) {
            $0.isSelecting = false
        }

        #expect(selectedServer == server)
    }

    @Test
    func test_view_serverTapped_ignoredWhileAlreadySelecting() async throws {
        let syncCount = LockIsolated(0)
        let store = TestStore(initialState: ServerRowReducer.State(
            isSelecting: true,
            server: .testValue(alias: "Other", id: "other")
        )) {
            ServerRowReducer()
        } withDependencies: {
            $0.updateCache.execute = { _ in
                syncCount.withValue { $0 += 1 }
            }
        }

        await store.send(.view(.serverTapped))

        #expect(syncCount.value == 0)
    }
}
