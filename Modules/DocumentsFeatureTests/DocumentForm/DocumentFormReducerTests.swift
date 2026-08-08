@testable import DocumentsFeature

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
struct DocumentFormReducerTests {

    @Test
    func test_destination_correspondentForm_delegate_correspondentSaved() async throws {
        let store = TestStore(initialState: DocumentFormReducer.State.testValue(
            destination: .correspondentForm(.testValue(correspondent: nil))
        )) {
            DocumentFormReducer()
        }

        await store.send(.destination(.presented(.correspondentForm(.delegate(.correspondentSaved(.testValue())))))) {
            $0.destination = nil
            $0.input.correspondent = .testValue()
        }
    }

    @Test
    func test_destination_documentTypeForm_delegate_documentTypeSaved() async throws {
        let store = TestStore(initialState: DocumentFormReducer.State.testValue(
            destination: .documentTypeForm(.testValue(documentType: nil))
        )) {
            DocumentFormReducer()
        }

        await store.send(.destination(.presented(.documentTypeForm(.delegate(.documentTypeSaved(.testValue())))))) {
            $0.destination = nil
            $0.input.documentType = .testValue()
        }
    }

    @Test
    func test_destination_storagePathForm_delegate_storagePathSaved() async throws {
        let store = TestStore(initialState: DocumentFormReducer.State.testValue(
            destination: .storagePathForm(.testValue(storagePath: nil))
        )) {
            DocumentFormReducer()
        }

        await store.send(.destination(.presented(.storagePathForm(.delegate(.storagePathSaved(.testValue())))))) {
            $0.destination = nil
            $0.input.storagePath = .testValue()
        }
    }

    @Test
    func test_destination_tagForm_delegate_tagSaved() async throws {
        let store = TestStore(initialState: DocumentFormReducer.State.testValue(
            destination: .tagForm(.testValue(tag: nil))
        )) {
            DocumentFormReducer()
        } withDependencies: {
            $0.apiCache.tag = { _, _ in .testValue() }
        }

        await store.send(.destination(.presented(.tagForm(.delegate(.tagSaved(.testValue())))))) {
            $0.destination = nil
            $0.input.storagePath = .testValue()
        }
    }

    @Test
    func test_view_createCorrespondentButtonTapped() async throws {
        let store = TestStore(initialState: DocumentFormReducer.State.testValue()) {
            DocumentFormReducer()
        }

        await store.send(.view(.createCorrespondentButtonTapped)) {
            $0.destination = .correspondentForm(.testValue(correspondent: nil))
        }
    }

    @Test
    func test_view_createDocumentTypeButtonTapped() async throws {
        let store = TestStore(initialState: DocumentFormReducer.State.testValue()) {
            DocumentFormReducer()
        }

        await store.send(.view(.createDocumentTypeButtonTapped)) {
            $0.destination = .documentTypeForm(.testValue(documentType: nil))
        }
    }

    @Test
    func test_view_createStoragePathButtonTapped() async throws {
        let store = TestStore(initialState: DocumentFormReducer.State.testValue()) {
            DocumentFormReducer()
        }

        await store.send(.view(.createStoragePathButtonTapped)) {
            $0.destination = .storagePathForm(.testValue(storagePath: nil))
        }
    }

    @Test
    func test_view_createTagButtonTapped() async throws {
        let store = TestStore(initialState: DocumentFormReducer.State.testValue()) {
            DocumentFormReducer()
        }

        await store.send(.view(.createTagButtonTapped)) {
            $0.destination = .tagForm(.testValue(tag: nil))
        }
    }

    @Test
    func test_view_closeButtonTapped() async throws {
        let dismissCalls = LockIsolated(0)
        let store = TestStore(initialState: DocumentFormReducer.State.testValue(
            destination: .documentTypeForm(.testValue())
        )) {
            DocumentFormReducer()
        } withDependencies: {
            $0.dismiss = .init {
                dismissCalls.withValue { $0 += 1 }
            }
        }

        await store.send(.view(.closeButtonTapped)) {
            $0.destination = nil
        }
        #expect(dismissCalls.value == 1)
    }

    @Test
    func test_view_getNextArchiveSerialNumberButtonTapped() async throws {
        let store = TestStore(initialState: DocumentFormReducer.State.testValue(
            destination: .documentTypeForm(.testValue())
        )) {
            DocumentFormReducer()
        } withDependencies: {
            $0.getNextArchiveSerialNumber.execute = { _ in 88 }
        }

        await store.send(.view(.getNextArchiveSerialNumberButtonTapped))
        await store.receive(\.binding, .set(\.isLoadingNextArchiveSerialNumber, true)) {
            $0.isLoadingNextArchiveSerialNumber = true
        }
        await store.receive(\.nextArchiveSerialNumber, 88) {
            $0.input.archiveSerialNumber = "88"
        }
        await store.receive(\.binding, .set(\.isLoadingNextArchiveSerialNumber, false)) {
            $0.isLoadingNextArchiveSerialNumber = false
        }
    }

    @Test
    func test_view_resetButtonTapped() async throws {
        let store = TestStore(initialState: DocumentFormReducer.State.testValue(
            document: .testValue()
        )) {
            DocumentFormReducer()
        }

        #expect(store.state.isModified == false)

        await store.send(.binding(.set(\.input.title, "some new title"))) {
            $0.input.title = "some new title"
        }

        #expect(store.state.isModified == true)

        await store.send(.view(.resetButtonTapped)) {
            $0.input.title = $0.document.title
        }

        #expect(store.state.isModified == false)
    }

    @Test
    func test_view_saveButtonTapped_success() async throws {
        let updatedDocument = Document.testValue(title: "some new title")
        let store = TestStore(initialState: DocumentFormReducer.State.testValue(
            document: .testValue()
        )) {
            DocumentFormReducer()
        } withDependencies: {
            $0.updateDocument.execute = { _, _, _ in
                updatedDocument
            }
        }

        await store.send(.binding(.set(\.input.title, "some new title"))) {
            $0.input.title = "some new title"
        }
        await store.send(.view(.saveButtonTapped))
        await store.receive(\.binding, .set(\.isUpdating, true)) {
            $0.isUpdating = true
        }
        await store.receive(\.updateResult.success, updatedDocument) {
            $0.document = updatedDocument
        }
        await store.receive(\.delegate.documentUpdated, updatedDocument)
        await store.receive(\.binding, .set(\.isUpdating, false)) {
            $0.isUpdating = false
        }
    }

    @Test
    func test_view_saveButtonTapped_failure() async throws {
        let toasts = LockIsolated<[Toast]>([])
        let store = TestStore(initialState: DocumentFormReducer.State.testValue(
            document: .testValue()
        )) {
            DocumentFormReducer()
        } withDependencies: {
            $0.toastPresenter.present = { value in
                toasts.withValue { $0.append(value) }
            }
            $0.updateDocument.execute = { _, _, _ in
                throw ApiError.testValue()
            }
        }

        await store.send(.binding(.set(\.input.title, "some new title"))) {
            $0.input.title = "some new title"
        }
        await store.send(.view(.saveButtonTapped))
        await store.receive(\.binding, .set(\.isUpdating, true)) {
            $0.isUpdating = true
        }
        await store.receive(\.updateResult.failure)
        await store.receive(\.binding, .set(\.isUpdating, false)) {
            $0.isUpdating = false
        }
    }
}
