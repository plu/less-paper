@testable import TagsFeature

import ApiInterface
import ComposableArchitecture
import Foundation
import SwiftSharing
import Testing

@MainActor
@Suite
struct TagRowReducerTests {

    @Test
    func test_view_deleteButtonTapped_cancelled() async throws {
        let store = TestStore(initialState: TagRowReducer.State(
            server: .testValue(),
            tag: .testValue(name: "Inbox")
        )) {
            TagRowReducer()
        } withDependencies: {
            $0.deleteConfirmation.present = { _, _ in false }
        }

        await store.send(.view(.deleteButtonTapped))
    }

    @Test
    func test_view_deleteButtonTapped_confirmed() async throws {
        let presented = LockIsolated<(title: LocalizedStringResource, name: String)?>(nil)
        let store = TestStore(initialState: TagRowReducer.State(
            server: .testValue(),
            tag: .testValue(name: "Inbox")
        )) {
            TagRowReducer()
        } withDependencies: {
            $0.deleteConfirmation.present = { title, name in
                presented.setValue((title, name))
                return true
            }
        }

        await store.send(.view(.deleteButtonTapped))
        await store.receive(\.delegate, .deleteTag)

        #expect(presented.value?.title == .deleteTag)
        #expect(presented.value?.name == "Inbox")
    }

    @Test
    func test_view_editButtonTapped() async throws {
        let store = TestStore(initialState: TagRowReducer.State(
            server: .testValue(),
            tag: .testValue()
        )) {
            TagRowReducer()
        }

        await store.send(.view(.editButtonTapped))
        await store.receive(\.delegate, .editTag)
    }

    // A snapshot proves a control is absent; it cannot prove the absence was caused by the right
    // permission. Gating tags on changeCorrespondent would compile, render identically in a
    // "cannot edit" snapshot, and be wrong.
    @Test
    func rowGatesOnTagPermissionsSpecifically() {
        let server = Server.testValue()

        @Shared(.currentUser(server))
        var user: User?

        @Shared(.permissions(server))
        var permissions: [Permission]?

        $user.withLock { $0 = .testValue(isSuperuser: false) }
        $permissions.withLock { $0 = [.changeTag] }

        let state = TagRowReducer.State(server: server, tag: .testValue())

        #expect(state.permissions.can(.changeTag))
        #expect(!state.permissions.can(.deleteTag))
        #expect(!state.permissions.can(.changeCorrespondent))
    }
}
