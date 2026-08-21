@testable import DocumentsFeature

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
    func test_updateResult_success_writesThroughSharedDocument() async throws {
        let updatedDocument = Document.testValue(title: "some new title")
        let document = Shared(value: Document.testValue())
        let store = TestStore(initialState: DocumentFormReducer.State(
            document: document,
            server: .testValue()
        )) {
            DocumentFormReducer()
        }

        await store.send(.updateResult(.success(updatedDocument))) {
            $0.$document.withLock { $0 = updatedDocument }
        }
        await store.receive(\.delegate.documentUpdated)

        #expect(document.wrappedValue == updatedDocument)
    }

    @Test
    func test_view_saveButtonTapped_success() async throws {
        let updatedDocument = Document.testValue(title: "some new title")
        let document = Shared(value: Document.testValue())
        let store = TestStore(initialState: DocumentFormReducer.State(
            document: document,
            server: .testValue()
        )) {
            DocumentFormReducer()
        } withDependencies: {
            $0.updateDocument.execute = { _, _, _ in
                updatedDocument
            }
        }
        store.exhaustivity = .off

        await store.send(.binding(.set(\.input.title, "some new title"))) {
            $0.input.title = "some new title"
        }
        await store.send(.view(.saveButtonTapped))
        await store.receive(\.binding, .set(\.isUpdating, true)) {
            $0.isUpdating = true
        }
        await store.receive(\.updateResult.success, updatedDocument)
        await store.receive(\.delegate.documentUpdated)
        await store.receive(\.binding, .set(\.isUpdating, false)) {
            $0.isUpdating = false
        }

        #expect(document.wrappedValue == updatedDocument)
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

    @Test
    func test_view_onAppear_seedsContentFromFullDocument() async throws {
        let full = Document.testValue(content: "Some invoice, and all the rest of the OCR text")
        let document = Shared(value: Document.testValue(content: "Some invoice"))
        let store = TestStore(initialState: DocumentFormReducer.State(
            document: document,
            server: .testValue()
        )) {
            DocumentFormReducer()
        } withDependencies: {
            $0.getDocument.execute = { _, _ in full }
        }

        await store.send(.view(.onAppear)) {
            $0.isLoadingDocument = true
        }
        await store.receive(\.documentResult.success, full) {
            $0.isLoadingDocument = false
            $0.content = full.content
            $0.$document.withLock { $0 = full }
        }

        #expect(document.wrappedValue == full)
        #expect(store.state.isModified == false)
    }

    @Test
    func test_documentResult_success_keepsEditsMadeWhileLoading() async throws {
        let full = Document.testValue(content: "Some invoice, and all the rest of the OCR text")
        // The fetch is held open so the edit below genuinely happens mid-flight.
        let gate = AsyncStream<Void>.makeStream()
        let store = TestStore(initialState: DocumentFormReducer.State.testValue(
            document: .testValue(content: "Some invoice")
        )) {
            DocumentFormReducer()
        } withDependencies: {
            $0.getDocument.execute = { _, _ in
                await gate.stream.first { _ in true }
                return full
            }
        }

        await store.send(.view(.onAppear)) {
            $0.isLoadingDocument = true
        }
        await store.send(.binding(.set(\.input.title, "typed while loading"))) {
            $0.input.title = "typed while loading"
        }

        gate.continuation.yield()
        gate.continuation.finish()

        await store.receive(\.documentResult.success, full) {
            $0.isLoadingDocument = false
            $0.content = full.content
            $0.$document.withLock { $0 = full }
        }

        #expect(store.state.input.title == "typed while loading")
    }

    @Test
    func test_view_onAppear_failure_setsLoadError() async throws {
        let toasts = LockIsolated<[Toast]>([])
        let store = TestStore(initialState: DocumentFormReducer.State.testValue()) {
            DocumentFormReducer()
        } withDependencies: {
            $0.getDocument.execute = { _, _ in throw ApiError.testValue() }
            $0.toastPresenter.present = { value in
                toasts.withValue { $0.append(value) }
            }
        }

        await store.send(.view(.onAppear)) {
            $0.isLoadingDocument = true
        }
        await store.receive(\.documentResult.failure) {
            $0.isLoadingDocument = false
            $0.loadError = ApiError.testValue().localizedDescription
        }

        #expect(store.state.content == nil)
        #expect(toasts.value.count == 1)

        // Re-appearing must not silently retry; only the retry button may.
        await store.send(.view(.onAppear))
    }

    @Test
    func test_view_retryLoadButtonTapped_afterFailure_refetches() async throws {
        let full = Document.testValue(content: "Some invoice, and all the rest of the OCR text")
        let store = TestStore(initialState: DocumentFormReducer.State.testValue(
            loadError: "The request timed out."
        )) {
            DocumentFormReducer()
        } withDependencies: {
            $0.getDocument.execute = { _, _ in full }
        }

        await store.send(.view(.retryLoadButtonTapped)) {
            $0.isLoadingDocument = true
            $0.loadError = nil
        }
        await store.receive(\.documentResult.success, full) {
            $0.isLoadingDocument = false
            $0.content = full.content
            $0.$document.withLock { $0 = full }
        }
    }

    @Test
    func test_view_onAppear_doesNotRefetchOnceLoaded() async throws {
        let calls = LockIsolated(0)
        let full = Document.testValue(content: "Some invoice, and all the rest of the OCR text")
        let store = TestStore(initialState: DocumentFormReducer.State.testValue()) {
            DocumentFormReducer()
        } withDependencies: {
            $0.getDocument.execute = { _, _ in
                calls.withValue { $0 += 1 }
                return full
            }
        }
        store.exhaustivity = .off

        await store.send(.view(.onAppear))
        await store.receive(\.documentResult.success)
        await store.send(.view(.onAppear))

        #expect(calls.value == 1)
    }

    @Test
    func test_contentEdit_flipsIsModified() async throws {
        let full = Document.testValue(content: "Some invoice, and all the rest of the OCR text")
        let store = TestStore(initialState: DocumentFormReducer.State.testValue()) {
            DocumentFormReducer()
        } withDependencies: {
            $0.getDocument.execute = { _, _ in full }
        }
        store.exhaustivity = .off

        await store.send(.view(.onAppear))
        await store.receive(\.documentResult.success)

        #expect(store.state.isModified == false)

        await store.send(.binding(.set(\.content, "edited content"))) {
            $0.content = "edited content"
        }

        #expect(store.state.isModified == true)

        await store.send(.binding(.set(\.content, full.content))) {
            $0.content = full.content
        }

        #expect(store.state.isModified == false)
    }

    @Test
    func test_view_saveButtonTapped_beforeLoad_omitsContent() async throws {
        let inputs = LockIsolated<[UpdateDocumentInput]>([])
        let store = TestStore(initialState: DocumentFormReducer.State.testValue(
            document: .testValue(content: "Some invoice")
        )) {
            DocumentFormReducer()
        } withDependencies: {
            $0.updateDocument.execute = { _, input, _ in
                inputs.withValue { $0.append(input) }
                return .testValue()
            }
        }
        store.exhaustivity = .off

        await store.send(.binding(.set(\.input.title, "some new title"))) {
            $0.input.title = "some new title"
        }
        await store.send(.view(.saveButtonTapped))
        await store.receive(\.updateResult.success)

        // The document came from the list, so its content is truncated. Sending it back would
        // overwrite the real text with a stump.
        #expect(inputs.value.count == 1)
        #expect(inputs.value.first?.content == nil)
    }

    @Test
    func test_view_saveButtonTapped_sendsContentOnlyWhenChanged() async throws {
        let inputs = LockIsolated<[UpdateDocumentInput]>([])
        let full = Document.testValue(content: "Some invoice, and all the rest of the OCR text")
        let store = TestStore(initialState: DocumentFormReducer.State.testValue()) {
            DocumentFormReducer()
        } withDependencies: {
            $0.getDocument.execute = { _, _ in full }
            $0.updateDocument.execute = { _, input, _ in
                inputs.withValue { $0.append(input) }
                return full
            }
        }
        store.exhaustivity = .off

        await store.send(.view(.onAppear))
        await store.receive(\.documentResult.success)

        await store.send(.binding(.set(\.input.title, "some new title")))
        await store.send(.view(.saveButtonTapped))
        await store.receive(\.updateResult.success)

        #expect(inputs.value.last?.content == nil)

        await store.send(.binding(.set(\.content, "edited content")))
        await store.send(.view(.saveButtonTapped))
        await store.receive(\.updateResult.success)

        #expect(inputs.value.last?.content == "edited content")
    }

    @Test
    func test_view_resetButtonTapped_beforeLoad_leavesContentNil() async throws {
        let store = TestStore(initialState: DocumentFormReducer.State.testValue(
            document: .testValue(content: "Some invoice")
        )) {
            DocumentFormReducer()
        }

        await store.send(.view(.resetButtonTapped))

        #expect(store.state.content == nil)
    }

    @Test
    func test_view_resetButtonTapped_restoresLoadedContent() async throws {
        let full = Document.testValue(content: "Some invoice, and all the rest of the OCR text")
        let store = TestStore(initialState: DocumentFormReducer.State.testValue()) {
            DocumentFormReducer()
        } withDependencies: {
            $0.getDocument.execute = { _, _ in full }
        }
        store.exhaustivity = .off

        await store.send(.view(.onAppear))
        await store.receive(\.documentResult.success)
        await store.send(.binding(.set(\.content, "edited content")))

        #expect(store.state.isModified == true)

        await store.send(.view(.resetButtonTapped))

        #expect(store.state.content == full.content)
        #expect(store.state.isModified == false)
    }
}
