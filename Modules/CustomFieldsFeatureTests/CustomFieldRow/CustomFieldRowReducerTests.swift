@testable import CustomFieldsFeature

import ApiInterface
import Components
import ComposableArchitecture
import Foundation
import SwiftSharing
import Testing
import TestSupport

@MainActor
@Suite
struct CustomFieldRowReducerTests {

    @Test
    func test_view_deleteButtonTapped_confirmed() async throws {
        let confirmationReceived = LockIsolated<String?>(nil)
        let store = TestStore(initialState: CustomFieldRowReducer.State(
            server: .testValue(),
            customField: .testValue(name: "Status")
        )) {
            CustomFieldRowReducer()
        } withDependencies: {
            $0.deleteConfirmation.present = { _, name in
                confirmationReceived.setValue(name)
                return true
            }
        }

        await store.send(.view(.deleteButtonTapped))
        await store.receive(\.delegate, .deleteCustomField)
        #expect(confirmationReceived.value == "Status")
    }

    @Test
    func test_view_deleteButtonTapped_cancelled() async throws {
        let store = TestStore(initialState: CustomFieldRowReducer.State(
            server: .testValue(),
            customField: .testValue()
        )) {
            CustomFieldRowReducer()
        } withDependencies: {
            $0.deleteConfirmation.present = { _, _ in false }
        }

        await store.send(.view(.deleteButtonTapped))
    }

    @Test
    func test_view_editButtonTapped() async throws {
        let store = TestStore(initialState: CustomFieldRowReducer.State(
            server: .testValue(),
            customField: .testValue()
        )) {
            CustomFieldRowReducer()
        }

        await store.send(.view(.editButtonTapped))
        await store.receive(\.delegate, .editCustomField)
    }

    // A snapshot proves a control is absent; it cannot prove the absence was caused by the right
    // permission. Gating custom fields on changeTag would compile and look identical.
    @Test
    func rowGatesOnCustomFieldPermissionsSpecifically() {
        let server = Server.testValue()

        @Shared(.currentUser(server))
        var user: User?

        @Shared(.permissions(server))
        var permissions: [Permission]?

        $user.withLock { $0 = .testValue(isSuperuser: false) }
        $permissions.withLock { $0 = [.changeCustomfield] }

        let state = CustomFieldRowReducer.State(server: server, customField: .testValue())

        #expect(state.canEdit)
        #expect(!state.canDelete)
        #expect(!state.permissions.can(.changeTag))
    }
}
