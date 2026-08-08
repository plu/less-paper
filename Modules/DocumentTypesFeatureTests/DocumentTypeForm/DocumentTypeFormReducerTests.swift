@testable import DocumentTypesFeature

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
struct DocumentTypeFormReducerTests {

    @Test
    func test_permissionForm_permissionsUpdated() async throws {
        let store = TestStore(initialState: DocumentTypeFormReducer.State(
            server: .testValue()
        )) {
            DocumentTypeFormReducer()
        }

        await store.send(.permissionsForm(.delegate(.permissionsUpdated(.testValue())))) {
            $0.input.owner = .value(1)
            $0.input.setPermissions = .testValue()
        }
    }

    @Test
    func test_view_cancelButtonTapped() async throws {
        var isDismissed = false
        let store = TestStore(initialState: DocumentTypeFormReducer.State(
            server: .testValue()
        )) {
            DocumentTypeFormReducer()
        } withDependencies: {
            $0.dismiss = .init { isDismissed = true }
        }

        await store.send(.view(.cancelButtonTapped))
        #expect(isDismissed == true)
    }

    @Test
    func test_view_saveButtonTapped_success() async throws {
        let store = TestStore(initialState: DocumentTypeFormReducer.State(
            server: .testValue()
        )) {
            DocumentTypeFormReducer()
        } withDependencies: {
            $0.saveDocumentType.execute = { _, _, _ in .testValue() }
        }

        await store.send(.view(.saveButtonTapped))
        await store.receive(\.binding, .set(\.isSaving, true)) {
            $0.isSaving = true
        }
        await store.receive(\.delegate.documentTypeSaved, .testValue())
        await store.receive(\.binding, .set(\.isSaving, false)) {
            $0.isSaving = false
        }
    }

    @Test
    func test_view_saveButtonTapped_toastError() async throws {
        let toasts = LockIsolated<[Toast]>([])
        let store = TestStore(initialState: DocumentTypeFormReducer.State(
            server: .testValue()
        )) {
            DocumentTypeFormReducer()
        } withDependencies: {
            $0.saveDocumentType.execute = { _, _, _ in throw ApiError.testValue() }
            $0.toastPresenter.present = { value in
                toasts.withValue { $0.append(value) }
            }
        }

        await store.send(.view(.saveButtonTapped))
        await store.receive(\.binding, .set(\.isSaving, true)) {
            $0.isSaving = true
        }
        await store.receive(\.error)
        await store.receive(\.binding, .set(\.isSaving, false)) {
            $0.isSaving = false
        }
        #expect(toasts.value == [.error("Something went wrong")])
    }

    @Test
    func test_view_saveButtonTapped_fieldErrors() async throws {
        let toasts = LockIsolated<[Toast]>([])
        let store = TestStore(initialState: DocumentTypeFormReducer.State(
            server: .testValue()
        )) {
            DocumentTypeFormReducer()
        } withDependencies: {
            $0.saveDocumentType.execute = { _, _, _ in
                throw ApiError.testValue(fieldErrors: [
                    "match": ["Match is mandatory."],
                    "name": ["Name is mandatory."]
                ])
            }
            $0.toastPresenter.present = { value in
                toasts.withValue { $0.append(value) }
            }
        }

        await store.send(.view(.saveButtonTapped))
        await store.receive(\.binding, .set(\.isSaving, true)) {
            $0.isSaving = true
        }
        await store.receive(\.error) {
            $0.input.match.error = "Match is mandatory."
            $0.input.name.error = "Name is mandatory."
        }
        await store.receive(\.binding, .set(\.isSaving, false)) {
            $0.isSaving = false
        }
        #expect(toasts.value == [.error("Some fields have errors")])
    }
}
