@testable import StoragePathsFeature

import ApiInterface
import Components
import ComposableArchitecture
import Foundation
import Testing

@MainActor
@Suite
struct StoragePathListReducerTests {

    @Test
    func test_destination_presented_storagePathForm_delegate_storagePathSaved_insert() async throws {
        let store = TestStore(initialState: StoragePathListReducer.State(
            storagePaths: [.testValue()],
            destination: .storagePathForm(StoragePathFormReducer.State(server: .testValue())),
            server: .testValue()
        )) {
            StoragePathListReducer()
        }

        await store.send(.destination(.presented(.storagePathForm(.delegate(.storagePathSaved(.testValue(
            id: 2,
            name: "New name"
        ))))))) {
            $0.destination = nil
            $0.storagePaths = [
                .testValue(storagePath: .testValue(id: 2, name: "New name")),
                .testValue()
            ]
        }
    }

    @Test
    func test_destination_presented_storagePathForm_delegate_storagePathSaved_update() async throws {
        @Shared(.storagePaths(.testValue()))
        var cachedStoragePaths = .init()

        let store = TestStore(initialState: StoragePathListReducer.State(
            storagePaths: [.testValue()],
            destination: .storagePathForm(StoragePathFormReducer.State(storagePath: .testValue(), server: .testValue())),
            server: .testValue()
        )) {
            StoragePathListReducer()
        }

        await store.send(.destination(.presented(.storagePathForm(.delegate(.storagePathSaved(.testValue(name: "New name"))))))) {
            $0.destination = nil
            $0.storagePaths = [.testValue(storagePath: .testValue(name: "New name"))]
        }
    }

    @Test
    func test_storagePaths_element_delegate_deleteStoragePath_error() async throws {
        @Shared(.storagePaths(.testValue()))
        var cachedStoragePaths = .init(uniqueElements: [.testValue()])

        let toasts = LockIsolated<[Toast]>([])
        let store = TestStore(initialState: StoragePathListReducer.State(
            storagePaths: [.testValue()],
            server: .testValue()
        )) {
            StoragePathListReducer()
        } withDependencies: {
            $0.deleteStoragePath.execute = { _, _ in
                throw ApiError.testValue()
            }
            $0.toastPresenter.present = { value in
                toasts.withValue { $0.append(value) }
            }
        }

        await store.send(.storagePaths(.element(id: 1, action: .delegate(.deleteStoragePath))))
        await store.receive(\.isUpdating) {
            $0.storagePaths[id: 1]?.isUpdating = true
        }
        await store.receive(\.error)
        await store.receive(\.isUpdating) {
            $0.storagePaths[id: 1]?.isUpdating = false
        }
        #expect(toasts.value == [.error("Something went wrong")])
    }

    @Test
    func test_storagePaths_element_delegate_deleteStoragePath_success() async throws {
        @Shared(.storagePaths(.testValue()))
        var cachedStoragePaths = .init()

        let deleteStoragePathReceived = LockIsolated<StoragePath.Id?>(nil)
        let store = TestStore(initialState: StoragePathListReducer.State(
            storagePaths: [.testValue()],
            server: .testValue()
        )) {
            StoragePathListReducer()
        } withDependencies: {
            $0.deleteStoragePath.execute = { id, _ in
                deleteStoragePathReceived.setValue(id)
            }
        }

        await store.send(.storagePaths(.element(id: 1, action: .delegate(.deleteStoragePath))))
        await store.receive(\.isUpdating) {
            $0.storagePaths[id: 1]?.isUpdating = true
        }
        await store.receive(\.storagePathDeleted) {
            $0.storagePaths = []
        }
    }

    @Test
    func test_storagePaths_element_delegate_editStoragePath() async throws {
        let store = TestStore(initialState: StoragePathListReducer.State(
            storagePaths: [.testValue()],
            server: .testValue()
        )) {
            StoragePathListReducer()
        }

        await store.send(.storagePaths(.element(id: 1, action: .delegate(.editStoragePath)))) {
            $0.destination = .storagePathForm(StoragePathFormReducer.State(
                storagePath: .testValue(),
                server: .testValue()
            ))
        }
    }

    @Test
    func test_view_createButtonTapped() async throws {
        let store = TestStore(initialState: StoragePathListReducer.State(
            storagePaths: [.testValue()],
            server: .testValue()
        )) {
            StoragePathListReducer()
        }

        await store.send(.view(.createStoragePathButtonTapped)) {
            $0.destination = .storagePathForm(StoragePathFormReducer.State(
                server: .testValue()
            ))
        }
    }

    @Test
    func test_view_onAppear_success() async throws {
        @Shared(.storagePaths(.testValue()))
        var cachedStoragePaths = .init()

        let getStoragePathsResult = [StoragePath.testValue()]
        let store = TestStore(initialState: StoragePathListReducer.State(server: .testValue())) {
            StoragePathListReducer()
        } withDependencies: {
            $0.getStoragePaths.execute = { _ in getStoragePathsResult }
        }

        await store.send(.view(.onAppear))
        await store.receive(\.getStoragePathsResult, getStoragePathsResult) {
            $0.storagePaths = IdentifiedArray(
                uniqueElements: getStoragePathsResult.map {
                    StoragePathRowReducer.State(
                        storagePath: $0,
                        server: .testValue()
                    )
                }
            )
        }
        await store.receive(\.binding, .set(\.isLoaded, true)) {
            $0.isLoaded = true
        }
    }
}
