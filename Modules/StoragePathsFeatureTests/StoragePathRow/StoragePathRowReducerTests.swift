@testable import StoragePathsFeature

import ApiInterface
import ComposableArchitecture
import Foundation
import Testing

@MainActor
@Suite
struct StoragePathRowReducerTests {

    @Test
    func test_destination_confirmation_deleteButtonTapped() async throws {
        let store = TestStore(initialState: StoragePathRowReducer.State(
            storagePath: .testValue(),
            destination: .confirmation(.confirmDelete(name: "Inbox")),
            server: .testValue()
        )) {
            StoragePathRowReducer()
        }

        await store.send(.destination(.presented(.confirmation(.deleteButtonTapped)))) {
            $0.destination = nil
        }
        await store.receive(\.delegate, .deleteStoragePath)
    }

    @Test
    func test_view_deleteButtonTapped() async throws {
        let storagePath = StoragePath.testValue()
        let store = TestStore(initialState: StoragePathRowReducer.State(
            storagePath: storagePath,
            server: .testValue()
        )) {
            StoragePathRowReducer()
        }

        await store.send(.view(.deleteButtonTapped)) {
            $0.destination = .confirmation(.confirmDelete(name: storagePath.name))
        }
    }

    @Test
    func test_view_editButtonTapped() async throws {
        let store = TestStore(initialState: StoragePathRowReducer.State(
            storagePath: .testValue(),
            server: .testValue()
        )) {
            StoragePathRowReducer()
        }

        await store.send(.view(.editButtonTapped))
        await store.receive(\.delegate, .editStoragePath)
    }
}
