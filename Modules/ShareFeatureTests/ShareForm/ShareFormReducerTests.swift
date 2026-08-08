@testable import ShareFeature

import ApiInterface
import Components
import ComposableArchitecture
import CorrespondentsFeature
import DocumentTypesFeature
import Foundation
import StoragePathsFeature
import TagsFeature
import Testing
import TestSupport

@MainActor
@Suite(
    .dependencies()
)
struct ShareFormReducerTests {

    @Test
    func test_changeServer_reset() async throws {
        let store = TestStore(initialState: ShareFormReducer.State.testValue()) {
            ShareFormReducer()
        }

        await store.send(.binding(.set(\.input.correspondent, .testValue()))) {
            $0.input.correspondent = .testValue()
        }
        await store.send(.binding(.set(\.input.documentType, .testValue()))) {
            $0.input.documentType = .testValue()
        }
        await store.send(.binding(.set(\.input.storagePath, .testValue()))) {
            $0.input.storagePath = .testValue()
        }
        await store.send(.binding(.set(\.input.tags, [.testValue()]))) {
            $0.input.tags = [.testValue()]
        }
        await store.send(.binding(.set(\.input.title, "Custom title"))) {
            $0.input.title = "Custom title"
        }

        #expect(store.state.input.correspondent == .testValue())
        #expect(store.state.input.documentType == .testValue())
        #expect(store.state.input.storagePath == .testValue())
        #expect(store.state.input.tags == [.testValue()])
        #expect(store.state.input.title == "Custom title")

        await store.send(.binding(.set(\.server, .testValue(id: "c0ff33")))) {
            $0.server = .testValue(id: "c0ff33")
            $0.input.correspondent = nil
            $0.input.documentType = nil
            $0.input.storagePath = nil
            $0.input.tags = []
        }

        #expect(store.state.input.correspondent == nil)
        #expect(store.state.input.documentType == nil)
        #expect(store.state.input.storagePath == nil)
        #expect(store.state.input.tags == [])
        #expect(store.state.input.title == "Custom title")
    }

    @Test
    func test_view_createCorrespondentButtonTapped() async throws {
        let correspondent = Correspondent.testValue()
        let store = TestStore(initialState: ShareFormReducer.State.testValue()) {
            ShareFormReducer()
        }

        await store.send(.view(.createCorrespondentButtonTapped)) {
            $0.destination = .correspondentForm(CorrespondentFormReducer.State.testValue(
                correspondent: nil
            ))
        }

        await store.send(.destination(.presented(.correspondentForm(.delegate(.correspondentSaved(correspondent)))))) {
            $0.destination = nil
            $0.input.correspondent = correspondent
        }
    }

    @Test
    func test_view_createDocumentTypeButtonTapped() async throws {
        let documentType = DocumentType.testValue()
        let store = TestStore(initialState: ShareFormReducer.State.testValue()) {
            ShareFormReducer()
        }

        await store.send(.view(.createDocumentTypeButtonTapped)) {
            $0.destination = .documentTypeForm(DocumentTypeFormReducer.State.testValue(
                documentType: nil
            ))
        }

        await store.send(.destination(.presented(.documentTypeForm(.delegate(.documentTypeSaved(documentType)))))) {
            $0.destination = nil
            $0.input.documentType = documentType
        }
    }

    @Test
    func test_view_createStoragePathButtonTapped() async throws {
        let storagePath = StoragePath.testValue()
        let store = TestStore(initialState: ShareFormReducer.State.testValue()) {
            ShareFormReducer()
        }

        await store.send(.view(.createStoragePathButtonTapped)) {
            $0.destination = .storagePathForm(StoragePathFormReducer.State.testValue(
                storagePath: nil
            ))
        }

        await store.send(.destination(.presented(.storagePathForm(.delegate(.storagePathSaved(storagePath)))))) {
            $0.destination = nil
            $0.input.storagePath = storagePath
        }
    }

    @Test
    func test_view_createTagButtonTapped() async throws {
        let tag = Tag.testValue()
        let store = TestStore(initialState: ShareFormReducer.State.testValue()) {
            ShareFormReducer()
        }

        await store.send(.view(.createTagButtonTapped)) {
            $0.destination = .tagForm(TagFormReducer.State.testValue(
                tag: nil
            ))
        }

        await store.send(.destination(.presented(.tagForm(.delegate(.tagSaved(tag)))))) {
            $0.destination = nil
            $0.input.tags = [tag]
        }
    }

    @Test
    func test_view_getNextArchiveSerialNumberTapped() async throws {
        let store = TestStore(initialState: ShareFormReducer.State.testValue()) {
            ShareFormReducer()
        } withDependencies: {
            $0.getNextArchiveSerialNumber.execute = { _ in
                42
            }
        }

        await store.send(.view(.getNextArchiveSerialNumberButtonTapped))
        await store.receive(\.binding, .set(\.isLoadingNextArchiveSerialNumber, true)) {
            $0.isLoadingNextArchiveSerialNumber = true
        }
        await store.receive(\.nextArchiveSerialNumber, 42) {
            $0.input.archiveSerialNumber = "42"
        }
        await store.receive(\.binding, .set(\.isLoadingNextArchiveSerialNumber, false)) {
            $0.isLoadingNextArchiveSerialNumber = false
        }
    }

    @Test
    func test_view_importButtonTapped() async throws {
        let createDocumentInput = LockIsolated([CreateDocumentInput]())
        let store = TestStore(initialState: ShareFormReducer.State.testValue(
            files: [
                .testPDF(named: "Puky.pdf"),
                .testPDF(named: "TonieBox.pdf"),
                .testPDF(named: "W-8BEN.pdf"),
            ]
        )) {
            ShareFormReducer()
        } withDependencies: {
            $0.createDocument.execute = { input, _ in
                createDocumentInput.withValue { $0.append(input) }
            }
        }

        await store.send(.view(.importButtonTapped))
        await store.receive(\.binding, .set(\.isImporting, true)) {
            $0.isImporting = true
        }
        await store.receive(\.binding, .set(\.isImporting, false)) {
            $0.isImporting = false
        }

        await store.withExhaustivity(.off(showSkippedAssertions: false)) {
            await store.receive(\.fileImported) {
                $0.currentIndex = 1
                $0.input.title = "TonieBox"
            }
        }

        await store.send(.view(.importButtonTapped))
        await store.receive(\.binding, .set(\.isImporting, true)) {
            $0.isImporting = true
        }
        await store.receive(\.binding, .set(\.isImporting, false)) {
            $0.isImporting = false
        }

        await store.withExhaustivity(.off(showSkippedAssertions: false)) {
            await store.receive(\.fileImported) {
                $0.currentIndex = 2
                $0.input.title = "W-8BEN"
            }
        }

        await store.send(.view(.importButtonTapped))
        await store.receive(\.binding, .set(\.isImporting, true)) {
            $0.isImporting = true
        }
        await store.receive(\.binding, .set(\.isImporting, false)) {
            $0.isImporting = false
        }
        await store.receive(\.fileImported)
        await store.receive(\.delegate, .dismiss)

        #expect(createDocumentInput.value.map(\.title) == [
            "Puky",
            "TonieBox",
            "W-8BEN",
        ])
        #expect(createDocumentInput.value.map(\.url) == [
            .testPDF(named: "Puky.pdf"),
            .testPDF(named: "TonieBox.pdf"),
            .testPDF(named: "W-8BEN.pdf"),
        ])
    }

    @Test
    func test_view_skipButtonTapped() async throws {
        let createDocumentCalled = LockIsolated(false)
        let store = TestStore(initialState: ShareFormReducer.State.testValue(
            files: [
                .testPDF(named: "Puky.pdf"),
                .testPDF(named: "TonieBox.pdf"),
                .testPDF(named: "W-8BEN.pdf"),
            ]
        )) {
            ShareFormReducer()
        } withDependencies: {
            $0.createDocument.execute = { _, _ in
                createDocumentCalled.setValue(true)
            }
        }

        await store.withExhaustivity(.off(showSkippedAssertions: false)) {
            await store.send(.view(.skipButtonTapped)) {
                $0.currentIndex = 1
                $0.input.title = "TonieBox"
            }

            await store.send(.view(.skipButtonTapped)) {
                $0.currentIndex = 2
                $0.input.title = "W-8BEN"
            }
        }

        await store.send(.view(.skipButtonTapped))
        await store.receive(\.delegate, .dismiss)

        #expect(createDocumentCalled.value == false)
    }

    @Test
    func test_view_unlockButtonTapped_failure() async throws {
        let toasts = LockIsolated<[Toast]>([])
        let file = try URL.testPDF(named: "Puky-Locked.pdf").temporaryCopy()
        let store = TestStore(initialState: ShareFormReducer.State.testValue(
            files: [file]
        )) {
            ShareFormReducer()
        } withDependencies: {
            $0.createDocument.execute = { _, _ in }
            $0.toastPresenter.present = { value in
                toasts.withValue { $0.append(value) }
            }
        }

        await store.withExhaustivity(.off(showSkippedAssertions: false)) {
            await store.send(\.binding, .set(\.input.password, "asdf"))
            await store.send(.view(.unlockButtonTapped)) {
                $0.currentIndex = 0
                $0.input.title = "Puky-Locked"
            }
        }

        await store.receive(\.error)
        #expect(toasts.value == [.error("Unlock failed")])
    }

    @Test
    func test_view_unlockButtonTapped_success() async throws {
        let file = try URL.testPDF(named: "Puky-Locked.pdf").temporaryCopy()
        let store = TestStore(initialState: ShareFormReducer.State.testValue(
            files: [file]
        )) {
            ShareFormReducer()
        } withDependencies: {
            $0.createDocument.execute = { _, _ in }
        }

        await store.withExhaustivity(.off(showSkippedAssertions: false)) {
            await store.send(\.binding, .set(\.input.password, "secret"))
            await store.send(.view(.unlockButtonTapped)) {
                $0.currentIndex = 0
                $0.input.title = "Puky-Locked"
            }
            await store.receive(\.fileUnlocked)
        }
    }
}
