@testable import SettingsFeature

import ApiInterface
import Components
import ComposableArchitecture
import Foundation
import Testing
import TestSupport

@MainActor
@Suite(
    .dependencies()
)
struct FavoriteSettingsReducerTests {

    @Test
    func test_onAppearLoadsTheSizeOnDisk() async {
        let store = TestStore(initialState: FavoriteSettingsReducer.State(server: .testValue())) {
            FavoriteSettingsReducer()
        } withDependencies: {
            $0.favoritesStore.totalByteCount = { _ in 4096 }
        }

        await store.send(.view(.onAppear))
        await store.receive(\.totalByteCountLoaded) { $0.totalByteCount = 4096 }
    }

    @Test
    func test_removeAllClearsRecordsAndFiles() async {
        let server = Server.testValue()
        let deleted = LockIsolated(false)

        @Shared(.favorites(server)) var favorites: IdentifiedArrayOf<FavoriteDocument> = [
            .testValue(document: .testValue(id: 7))
        ]

        let store = TestStore(initialState: FavoriteSettingsReducer.State(
            server: server,
            totalByteCount: 4096
        )) {
            FavoriteSettingsReducer()
        } withDependencies: {
            $0.deleteConfirmation.present = { _, _ in true }
            $0.favoritesStore.deleteAll = { _ in deleted.setValue(true) }
        }

        await store.send(.view(.removeAllButtonTapped))
        await store.receive(\.removeConfirmed) { $0.isWorking = true }
        await store.receive(\.removed) {
            $0.isWorking = false
            $0.totalByteCount = 0
        }

        #expect(deleted.value)
        #expect($favorites.wrappedValue.isEmpty)
    }

    // Declining leaves both buttons live, which is why `isWorking` is set by `removeConfirmed`
    // rather than by the tap.
    @Test
    func test_decliningTheConfirmationRemovesNothing() async {
        let server = Server.testValue(id: "declining-removes-nothing")
        let deleted = LockIsolated(false)

        @Shared(.favorites(server)) var favorites: IdentifiedArrayOf<FavoriteDocument> = [
            .testValue(document: .testValue(id: 7))
        ]

        let store = TestStore(initialState: FavoriteSettingsReducer.State(server: server)) {
            FavoriteSettingsReducer()
        } withDependencies: {
            $0.deleteConfirmation.present = { _, _ in false }
            $0.favoritesStore.deleteAll = { _ in deleted.setValue(true) }
        }

        await store.send(.view(.removeAllButtonTapped))
        await store.finish()

        #expect(!deleted.value)
        #expect(store.state.isWorking == false)
        #expect($favorites.wrappedValue.count == 1)
    }

    @Test
    func test_aFailedRemoveReportsAndRereadsTheSize() async {
        let server = Server.testValue(id: "failed-remove")
        let toasts = LockIsolated([Toast]())

        @Shared(.favorites(server)) var favorites: IdentifiedArrayOf<FavoriteDocument> = [
            .testValue(document: .testValue(id: 7))
        ]

        let store = TestStore(initialState: FavoriteSettingsReducer.State(
            server: server,
            totalByteCount: 4096
        )) {
            FavoriteSettingsReducer()
        } withDependencies: {
            $0.deleteConfirmation.present = { _, _ in true }
            $0.favoritesStore.deleteAll = { _ in throw TestError.someError }
            $0.favoritesStore.totalByteCount = { _ in 512 }
            $0.toastPresenter.present = { value in toasts.withValue { $0.append(value) } }
        }

        await store.send(.view(.removeAllButtonTapped))
        await store.receive(\.removeConfirmed) { $0.isWorking = true }
        await store.receive(\.removeFailed) { $0.isWorking = false }
        await store.receive(\.totalByteCountLoaded) { $0.totalByteCount = 512 }
        await store.finish()

        #expect(toasts.value == [.error("TestError.someError")])
        // The records go first, so a failure to delete the files still leaves none behind.
        #expect($favorites.wrappedValue.isEmpty)
    }

    @Test
    func test_redownloadAllForcesPhaseTwo() async {
        let forced = LockIsolated<Bool?>(nil)
        let toasts = LockIsolated([Toast]())

        let store = TestStore(initialState: FavoriteSettingsReducer.State(server: .testValue())) {
            FavoriteSettingsReducer()
        } withDependencies: {
            $0.favoritesStore.totalByteCount = { _ in 8192 }
            $0.refreshFavorites.execute = { force, _ in
                forced.setValue(force)
                return FavoriteRefreshResult(updated: 2)
            }
            $0.toastPresenter.present = { value in toasts.withValue { $0.append(value) } }
        }

        await store.send(.view(.redownloadAllButtonTapped)) { $0.isWorking = true }
        await store.receive(\.refreshResult) { $0.isWorking = false }
        // Redownloading rewrites every PDF, so the size has to be read again.
        await store.receive(\.totalByteCountLoaded) { $0.totalByteCount = 8192 }
        await store.finish()

        #expect(forced.value == true)
        #expect(toasts.value == [.success("2 favorites updated.")])
    }

    @Test
    func test_aFailedRedownloadReports() async {
        let toasts = LockIsolated([Toast]())

        let store = TestStore(initialState: FavoriteSettingsReducer.State(server: .testValue())) {
            FavoriteSettingsReducer()
        } withDependencies: {
            $0.refreshFavorites.execute = { _, _ in throw TestError.someError }
            $0.toastPresenter.present = { value in toasts.withValue { $0.append(value) } }
        }

        await store.send(.view(.redownloadAllButtonTapped)) { $0.isWorking = true }
        await store.receive(\.refreshResult) { $0.isWorking = false }
        await store.finish()

        #expect(toasts.value == [.error("TestError.someError")])
    }
}
