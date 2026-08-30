@testable import SettingsFeature

import ApiInterface
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
    func test_removeAllClearsRecordsAndFiles() async {
        let server = Server.testValue()
        let deleted = LockIsolated(false)

        @Shared(.favorites(server)) var favorites: IdentifiedArrayOf<FavoriteDocument> = [
            .testValue(document: .testValue(id: 7))
        ]

        let store = TestStore(initialState: FavoriteSettingsReducer.State(server: server)) {
            FavoriteSettingsReducer()
        } withDependencies: {
            $0.deleteConfirmation.present = { _, _ in true }
            $0.favoritesStore.deleteAll = { _ in deleted.setValue(true) }
        }

        await store.send(.view(.removeAllButtonTapped))
        await store.receive(\.removed) { $0.totalByteCount = 0 }

        #expect(deleted.value)
        #expect($favorites.wrappedValue.isEmpty)
    }

    @Test
    func test_redownloadAllForcesPhaseTwo() async {
        let forced = LockIsolated<Bool?>(nil)

        let store = TestStore(initialState: FavoriteSettingsReducer.State(server: .testValue())) {
            FavoriteSettingsReducer()
        } withDependencies: {
            $0.refreshFavorites.execute = { force, _ in forced.setValue(force); return .init() }
        }

        await store.send(.view(.redownloadAllButtonTapped)) { $0.isWorking = true }
        await store.receive(\.refreshResult) { $0.isWorking = false }

        #expect(forced.value == true)
    }
}
