@testable import CustomFieldsFeature

import ApiInterface
import Components
import ComposableArchitecture
import Foundation
import SwiftSharing
import Testing
import TestSupport

@MainActor
@Suite(
    .dependencies()
)
struct CustomFieldListReducerTests {

    @Test
    func test_destination_presented_customFieldForm_delegate_customFieldSaved_insert() async throws {
        let store = TestStore(initialState: CustomFieldListReducer.State(
            customFields: [.testValue()],
            destination: .customFieldForm(CustomFieldFormReducer.State(server: .testValue())),
            server: .testValue()
        )) {
            CustomFieldListReducer()
        }

        await store.send(.destination(.presented(.customFieldForm(.delegate(.customFieldSaved(.testValue(
            id: 2,
            name: "New name"
        ))))))) {
            $0.destination = nil
            $0.customFields = [
                .testValue(customField: .testValue(id: 2, name: "New name")),
                .testValue()
            ]
        }
    }

    @Test
    func test_destination_presented_customFieldForm_delegate_customFieldSaved_update() async throws {
        @Shared(.customFields(.testValue()))
        var cachedCustomFields = .init()

        let store = TestStore(initialState: CustomFieldListReducer.State(
            customFields: [.testValue()],
            destination: .customFieldForm(CustomFieldFormReducer.State(customField: .testValue(), server: .testValue())),
            server: .testValue()
        )) {
            CustomFieldListReducer()
        }

        await store.send(.destination(.presented(.customFieldForm(.delegate(.customFieldSaved(.testValue(name: "New name"))))))) {
            $0.destination = nil
            $0.customFields = [.testValue(customField: .testValue(name: "New name"))]
        }
    }

    @Test
    func test_customFields_element_delegate_deleteCustomField_error() async throws {
        @Shared(.customFields(.testValue()))
        var cachedCustomFields = .init(uniqueElements: [CustomField.testValue()])

        let toasts = LockIsolated<[Toast]>([])
        let store = TestStore(initialState: CustomFieldListReducer.State(
            customFields: [.testValue()],
            server: .testValue()
        )) {
            CustomFieldListReducer()
        } withDependencies: {
            $0.deleteCustomField.execute = { _, _ in
                throw ApiError.testValue()
            }
            $0.toastPresenter.present = { value in
                toasts.withValue { $0.append(value) }
            }
        }

        await store.send(.customFields(.element(id: 1, action: .delegate(.deleteCustomField))))
        await store.receive(\.isUpdating) {
            $0.customFields[id: 1]?.isUpdating = true
        }
        await store.receive(\.error)
        await store.receive(\.isUpdating) {
            $0.customFields[id: 1]?.isUpdating = false
        }
        #expect(toasts.value == [.error("Something went wrong")])
    }

    @Test
    func test_customFields_element_delegate_deleteCustomField_success() async throws {
        @Shared(.customFields(.testValue()))
        var cachedCustomFields = .init()

        let store = TestStore(initialState: CustomFieldListReducer.State(
            customFields: [.testValue()],
            server: .testValue()
        )) {
            CustomFieldListReducer()
        } withDependencies: {
            $0.deleteCustomField.execute = { _, _ in }
        }

        await store.send(.customFields(.element(id: 1, action: .delegate(.deleteCustomField))))
        await store.receive(\.isUpdating) {
            $0.customFields[id: 1]?.isUpdating = true
        }
        await store.receive(\.customFieldDeleted) {
            $0.customFields = []
        }
    }

    @Test
    func test_customFields_element_delegate_editCustomField() async throws {
        let store = TestStore(initialState: CustomFieldListReducer.State(
            customFields: [.testValue()],
            server: .testValue()
        )) {
            CustomFieldListReducer()
        }

        await store.send(.customFields(.element(id: 1, action: .delegate(.editCustomField)))) {
            $0.destination = .customFieldForm(CustomFieldFormReducer.State(
                customField: .testValue(),
                server: .testValue()
            ))
        }
    }

    @Test
    func test_view_createButtonTapped() async throws {
        let store = TestStore(initialState: CustomFieldListReducer.State(
            customFields: [.testValue()],
            server: .testValue()
        )) {
            CustomFieldListReducer()
        }

        await store.send(.view(.createCustomFieldButtonTapped)) {
            $0.destination = .customFieldForm(CustomFieldFormReducer.State(
                server: .testValue()
            ))
        }
    }

    @Test
    func test_view_onAppear_success() async throws {
        @Shared(.customFields(.testValue()))
        var cachedCustomFields = .init()

        let getCustomFieldsResult = [CustomField.testValue()]
        let store = TestStore(initialState: CustomFieldListReducer.State(server: .testValue())) {
            CustomFieldListReducer()
        } withDependencies: {
            $0.getCustomFields.execute = { _ in getCustomFieldsResult }
        }

        await store.send(.view(.onAppear))
        await store.receive(\.getCustomFieldsResult, getCustomFieldsResult) {
            $0.customFields = IdentifiedArray(
                uniqueElements: getCustomFieldsResult.map {
                    CustomFieldRowReducer.State(
                        server: .testValue(),
                        customField: $0
                    )
                }
            )
        }
        await store.receive(\.binding, .set(\.isLoaded, true)) {
            $0.isLoaded = true
        }
    }

    // The toolbar "+" is gated on .addCustomField, but this project's NavigationStack snapshots do
    // not render nav-bar chrome, so no image can show its absence. This asserts the gate instead -
    // and the third expectation is the one that catches gating custom fields on a neighbouring
    // entity's permission, which would compile and look identical.
    @Test
    func listGatesOnCustomFieldPermissionsSpecifically() {
        let server = Server.testValue()

        @Shared(.currentUser(server))
        var user: User?

        @Shared(.permissions(server))
        var permissions: [Permission]?

        $user.withLock { $0 = .testValue(isSuperuser: false) }
        $permissions.withLock { $0 = [.viewCustomField] }

        let state = CustomFieldListReducer.State(server: server)

        #expect(!state.permissions.can(.addCustomField))
        #expect(state.permissions.can(.viewCustomField))
        #expect(!state.permissions.can(.addTag))
    }

    // Fail open: nothing read means nothing known, so every control shows. This is the state a user
    // on a paperless that does not send the permissions key is in, and it must look like today.
    @Test
    func listAllowsEverythingWhenNothingHasBeenRead() {
        let state = CustomFieldListReducer.State(server: .testValue())

        #expect(state.permissions.can(.addCustomField))
    }
}
