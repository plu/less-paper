@testable import ServersFeature

import ApiInterface
import ComposableArchitecture
import Foundation
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
}
