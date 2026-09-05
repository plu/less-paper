@testable import SavedViewsFeature

import ApiInterface
import ComposableArchitecture
import Foundation
import SwiftSharing
import Testing

@MainActor
@Suite
struct SavedViewRowReducerTests {

    @Test
    func test_view_deleteButtonTapped_cancelled() async throws {
        let store = TestStore(initialState: SavedViewRowReducer.State.testValue()) {
            SavedViewRowReducer()
        } withDependencies: {
            $0.deleteConfirmation.present = { _, _ in false }
        }

        await store.send(.view(.deleteButtonTapped))
    }

    @Test
    func test_view_deleteButtonTapped_confirmed() async throws {
        let savedView = SavedView.testValue()
        let presented = LockIsolated<(title: LocalizedStringResource, name: String)?>(nil)
        let store = TestStore(initialState: SavedViewRowReducer.State.testValue(
            savedView: savedView
        )) {
            SavedViewRowReducer()
        } withDependencies: {
            $0.deleteConfirmation.present = { title, name in
                presented.setValue((title, name))
                return true
            }
        }

        await store.send(.view(.deleteButtonTapped))
        await store.receive(\.delegate, .deleteSavedView)

        #expect(presented.value?.title == .deleteSavedView)
        #expect(presented.value?.name == savedView.name)
    }

    @Test
    func test_view_editButtonTapped() async throws {
        let store = TestStore(initialState: SavedViewRowReducer.State.testValue()) {
            SavedViewRowReducer()
        }

        await store.send(.view(.editButtonTapped))
        await store.receive(\.delegate, .editSavedView)
    }

    // A snapshot proves a control is absent; it cannot prove the absence was caused by the right
    // permission. Gating saved views on changeTag would compile and look identical.
    @Test
    func rowGatesOnSavedViewPermissionsSpecifically() {
        let server = Server.testValue()

        @Shared(.currentUser(server))
        var user: User?

        @Shared(.permissions(server))
        var permissions: [Permission]?

        $user.withLock { $0 = .testValue(isSuperuser: false) }
        $permissions.withLock { $0 = [.changeSavedView] }

        let state = SavedViewRowReducer.State(server: server, savedView: .testValue())

        #expect(state.canEdit)
        #expect(!state.canDelete)
        #expect(!state.permissions.can(.changeTag))
    }
}
