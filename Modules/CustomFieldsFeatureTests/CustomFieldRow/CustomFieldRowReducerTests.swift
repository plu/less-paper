@testable import CustomFieldsFeature

import ApiInterface
import Components
import ComposableArchitecture
import Foundation
import Testing
import TestSupport

@MainActor
@Suite
struct CustomFieldRowReducerTests {

    @Test
    func test_view_deleteButtonTapped_confirmed() async throws {
        let confirmationReceived = LockIsolated<String?>(nil)
        let store = TestStore(initialState: CustomFieldRowReducer.State(
            customField: .testValue(name: "Status"),
            server: .testValue()
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
            customField: .testValue(),
            server: .testValue()
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
            customField: .testValue(),
            server: .testValue()
        )) {
            CustomFieldRowReducer()
        }

        await store.send(.view(.editButtonTapped))
        await store.receive(\.delegate, .editCustomField)
    }
}
