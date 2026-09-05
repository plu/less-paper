@testable import StoragePathsFeature

import ApiInterface
import ComposableArchitecture
import Foundation
import SwiftSharing
import Testing

@MainActor
@Suite
struct StoragePathRowReducerTests {

    @Test
    func test_view_deleteButtonTapped_cancelled() async throws {
        let store = TestStore(initialState: StoragePathRowReducer.State.testValue()) {
            StoragePathRowReducer()
        } withDependencies: {
            $0.deleteConfirmation.present = { _, _ in false }
        }

        await store.send(.view(.deleteButtonTapped))
    }

    @Test
    func test_view_deleteButtonTapped_confirmed() async throws {
        let storagePath = StoragePath.testValue()
        let presented = LockIsolated<(title: LocalizedStringResource, name: String)?>(nil)
        let store = TestStore(initialState: StoragePathRowReducer.State.testValue(
            storagePath: storagePath
        )) {
            StoragePathRowReducer()
        } withDependencies: {
            $0.deleteConfirmation.present = { title, name in
                presented.setValue((title, name))
                return true
            }
        }

        await store.send(.view(.deleteButtonTapped))
        await store.receive(\.delegate, .deleteStoragePath)

        #expect(presented.value?.title == .deleteStoragePath)
        #expect(presented.value?.name == storagePath.name)
    }

    @Test
    func test_view_editButtonTapped() async throws {
        let store = TestStore(initialState: StoragePathRowReducer.State.testValue()) {
            StoragePathRowReducer()
        }

        await store.send(.view(.editButtonTapped))
        await store.receive(\.delegate, .editStoragePath)
    }

    // A snapshot proves a control is absent; it cannot prove the absence was caused by the right
    // permission. Gating storage paths on changeTag would compile and look identical.
    @Test
    func rowGatesOnStoragePathPermissionsSpecifically() {
        let server = Server.testValue()

        @Shared(.currentUser(server))
        var user: User?

        @Shared(.permissions(server))
        var permissions: [Permission]?

        $user.withLock { $0 = .testValue(isSuperuser: false) }
        $permissions.withLock { $0 = [.changeStoragePath] }

        let state = StoragePathRowReducer.State(server: server, storagePath: .testValue())

        #expect(state.permissions.can(.changeStoragePath))
        #expect(!state.permissions.can(.deleteStoragePath))
        #expect(!state.permissions.can(.changeTag))
    }
}
