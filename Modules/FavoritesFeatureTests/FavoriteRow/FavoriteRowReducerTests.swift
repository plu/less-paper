@testable import FavoritesFeature

import ApiInterface
import ComposableArchitecture
import Foundation
import Testing

@MainActor
@Suite
struct FavoriteRowReducerTests {

    @Test
    func test_unfavoriteRemovesTheFavorite() async {
        let removed = LockIsolated<Document.Id?>(nil)
        let favorite = FavoriteDocument.testValue(document: .testValue(id: 7))

        let store = TestStore(
            initialState: FavoriteRowReducer.State(favorite: favorite, server: .testValue())
        ) {
            FavoriteRowReducer()
        } withDependencies: {
            $0.removeFavorite.execute = { id, _ in removed.setValue(id) }
        }

        await store.send(.view(.unfavoriteButtonTapped))

        #expect(removed.value == 7)
    }

    @Test
    func test_tappingTheRowAsksToOpenIt() async {
        let favorite = FavoriteDocument.testValue(document: .testValue(id: 7))

        let store = TestStore(
            initialState: FavoriteRowReducer.State(favorite: favorite, server: .testValue())
        ) {
            FavoriteRowReducer()
        }

        await store.send(.view(.rowTapped))
        await store.receive(\.delegate.open)
    }
}
