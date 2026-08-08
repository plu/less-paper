@testable import SavedViewsFeature

import ApiInterface
import ComposableArchitecture
import Foundation
import Testing

@MainActor
@Suite
struct SavedViewRowReducerTests {

    @Test
    func test_destination_confirmation_deleteButtonTapped() async throws {
        let store = TestStore(initialState: SavedViewRowReducer.State(
            savedView: .testValue(),
            destination: .confirmation(.confirmDelete(name: "Inbox")),
            server: .testValue()
        )) {
            SavedViewRowReducer()
        }

        await store.send(.destination(.presented(.confirmation(.deleteButtonTapped)))) {
            $0.destination = nil
        }
        await store.receive(\.delegate, .deleteSavedView)
    }

    @Test
    func test_view_deleteButtonTapped() async throws {
        let savedView = SavedView.testValue()
        let store = TestStore(initialState: SavedViewRowReducer.State(
            savedView: savedView,
            server: .testValue()
        )) {
            SavedViewRowReducer()
        }

        await store.send(.view(.deleteButtonTapped)) {
            $0.destination = .confirmation(.confirmDelete(name: savedView.name))
        }
    }

    @Test
    func test_view_editButtonTapped() async throws {
        let store = TestStore(initialState: SavedViewRowReducer.State(
            savedView: .testValue(),
            server: .testValue()
        )) {
            SavedViewRowReducer()
        }

        await store.send(.view(.editButtonTapped))
        await store.receive(\.delegate, .editSavedView)
    }
}
