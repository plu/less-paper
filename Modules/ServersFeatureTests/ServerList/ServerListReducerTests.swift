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
struct ServerListReducerTests {

    @Test
    func test_destination_presented_serverForm_delegate_serverSaved_insert() async throws {
        @Shared(.servers)
        var servers: IdentifiedArrayOf<Server>

        let input = ServerFormInput.testValue()
        let store = TestStore(initialState: ServerListReducer.State(
            destination: .serverForm(ServerFormReducer.State(input: input))
        )) {
            ServerListReducer()
        }

        await store.send(.destination(.presented(.serverForm(.delegate(.serverSaved(input.server)))))) {
            $0.destination = nil
            $0.servers = [.testValue(server: input.server)]
        }

        #expect(servers == [input.server])
    }

    @Test
    func test_destination_presented_serverForm_delegate_serverSaved_update() async throws {
        let server = Server.testValue(alias: "OLD")
        let updatedServer = Server.testValue(alias: "OLD")
        let input = ServerFormInput.testValue(id: server.id)

        @Shared(.servers)
        var servers: IdentifiedArrayOf<Server> = [server]

        let store = TestStore(initialState: ServerListReducer.State(
            destination: .serverForm(ServerFormReducer.State(input: input))
        )) {
            ServerListReducer()
        }

        await store.send(.destination(.presented(.serverForm(.delegate(.serverSaved(updatedServer)))))) {
            $0.destination = nil
            $0.servers = [.testValue(server: updatedServer)]
        }

        #expect(servers == [updatedServer])
    }

    @Test
    func test_servers_element_delegate_deleteServer() async throws {
        let server = Server.testValue()

        @Shared(.servers)
        var servers: IdentifiedArrayOf<Server> = [server]

        let store = TestStore(initialState: ServerListReducer.State()) {
            ServerListReducer()
        } withDependencies: {
            $0.favoritesStore.deleteAll = { _ in }
        }

        #expect(store.state.servers == [.testValue(server: server)])

        await store.send(.servers(.element(id: server.id, action: .delegate(.deleteServer)))) {
            $0.servers = []
        }

        await store.finish()

        #expect(servers == [])
    }

    @Test
    func test_deletingAServerDeletesItsFavorites() async throws {
        let server = Server.testValue(id: "deleting-a-server-deletes-its-favorites")
        let deleted = LockIsolated<Server?>(nil)

        @Shared(.servers)
        var servers: IdentifiedArrayOf<Server> = [server]

        @Shared(.favorites(server))
        var favorites: IdentifiedArrayOf<FavoriteDocument> = [
            .testValue(document: .testValue(id: 1))
        ]

        let store = TestStore(initialState: ServerListReducer.State()) {
            ServerListReducer()
        } withDependencies: {
            $0.favoritesStore.deleteAll = { deleted.setValue($0) }
        }

        await store.send(.servers(.element(id: server.id, action: .delegate(.deleteServer)))) {
            $0.servers = []
        }

        await store.finish()

        #expect(deleted.value?.id == server.id)
        #expect(favorites.isEmpty)
    }

    @Test
    func test_servers_element_delegate_editServer() async throws {
        let server = Server.testValue(headers: [.testValue()])

        @Shared(.servers)
        var servers: IdentifiedArrayOf<Server> = [server]

        let store = TestStore(initialState: ServerListReducer.State()) {
            ServerListReducer()
        } withDependencies: {
            $0.getCredentials.execute = { _ in .testValue() }
        }

        #expect(store.state.servers == [.testValue(server: server)])

        await store.send(.servers(.element(id: server.id, action: .delegate(.editServer))))
        await store.receive(\.getCredentialsResult) {
            $0.destination = .serverForm(ServerFormReducer.State(
                input: .testValue(headers: [.testValue()])
            ))
        }
    }

    @Test
    func test_view_createButtonTapped() async throws {
        let store = TestStore(initialState: ServerListReducer.State()) {
            ServerListReducer()
        } withDependencies: {
            $0.uuid = .constant(UUID(0))
        }

        await store.send(.view(.createServerButtonTapped)) {
            $0.destination = .serverForm(ServerFormReducer.State(
                input: .empty
            ))
        }
    }
}
