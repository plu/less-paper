@testable import CorrespondentsFeature

import ApiInterface
import ComposableArchitecture
import Foundation
import SwiftSharing
import Testing

@MainActor
@Suite
struct CorrespondentRowReducerTests {

    @Test
    func test_view_deleteButtonTapped_cancelled() async throws {
        let store = TestStore(initialState: CorrespondentRowReducer.State.testValue()) {
            CorrespondentRowReducer()
        } withDependencies: {
            $0.deleteConfirmation.present = { _, _ in false }
        }

        await store.send(.view(.deleteButtonTapped))
    }

    @Test
    func test_view_deleteButtonTapped_confirmed() async throws {
        let correspondent = Correspondent.testValue()
        let presented = LockIsolated<(title: LocalizedStringResource, name: String)?>(nil)
        let store = TestStore(initialState: CorrespondentRowReducer.State.testValue(
            correspondent: correspondent
        )) {
            CorrespondentRowReducer()
        } withDependencies: {
            $0.deleteConfirmation.present = { title, name in
                presented.setValue((title, name))
                return true
            }
        }

        await store.send(.view(.deleteButtonTapped))
        await store.receive(\.delegate, .deleteCorrespondent)

        #expect(presented.value?.title == .deleteCorrespondent)
        #expect(presented.value?.name == correspondent.name)
    }

    @Test
    func test_view_editButtonTapped() async throws {
        let store = TestStore(initialState: CorrespondentRowReducer.State.testValue()) {
            CorrespondentRowReducer()
        }

        await store.send(.view(.editButtonTapped))
        await store.receive(\.delegate, .editCorrespondent)
    }

    // A snapshot proves a control is absent; it cannot prove the absence was caused by the right
    // permission. Gating correspondents on changeTag would compile and look identical.
    @Test
    func rowGatesOnCorrespondentPermissionsSpecifically() {
        let server = Server.testValue()

        @Shared(.currentUser(server))
        var user: User?

        @Shared(.permissions(server))
        var permissions: [Permission]?

        $user.withLock { $0 = .testValue(isSuperuser: false) }
        $permissions.withLock { $0 = [.changeCorrespondent] }

        let state = CorrespondentRowReducer.State(server: server, correspondent: .testValue())

        #expect(state.canEdit)
        #expect(!state.canDelete)
        #expect(!state.permissions.can(.changeTag))
    }
}
