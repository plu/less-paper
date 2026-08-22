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
struct DocumentRowReducerTests {

    @Test
    func test_destination_documentForm_delegate_documentUpdated() async throws {
        let document = Document.testValue()
        let store = TestStore(initialState: DocumentRowReducer.State.testValue(
            document: document
        )) {
            DocumentRowReducer()
        }

        await store.send(.view(.editButtonTapped)) {
            $0.destination = .documentForm(.testValue())
        }
        await store.send(.destination(.presented(.documentForm(.delegate(.documentUpdated))))) {
            $0.destination = nil
        }
    }

    @Test(arguments: DocumentViewerSection.allCases)
    func test_view_viewButtonTapped(section: DocumentViewerSection) async throws {
        let store = TestStore(initialState: DocumentRowReducer.State.testValue()) {
            DocumentRowReducer()
        }

        await store.send(.view(.viewButtonTapped(section))) {
            $0.destination = .documentViewer(.testValue(section: section))
        }
    }

    @Test
    func test_view_deleteButtonTapped_confirmed() async throws {
        let documentTitle = LockIsolated<String?>(nil)
        let store = TestStore(initialState: DocumentRowReducer.State.testValue(
            document: .testValue(title: "Invoice")
        )) {
            DocumentRowReducer()
        } withDependencies: {
            $0.documentDeleteConfirmation.present = { title in
                documentTitle.setValue(title)
                return true
            }
        }

        await store.send(.view(.deleteButtonTapped))
        await store.receive(\.delegate, .deleteDocument)

        #expect(documentTitle.value == "Invoice")
    }

    @Test
    func test_view_deleteButtonTapped_cancelled() async throws {
        let store = TestStore(initialState: DocumentRowReducer.State.testValue(
            document: .testValue(title: "Invoice")
        )) {
            DocumentRowReducer()
        } withDependencies: {
            $0.documentDeleteConfirmation.present = { _ in false }
        }

        await store.send(.view(.deleteButtonTapped))
    }

    @Test
    func test_view_rowTapped() async throws {
        let document = Document.testValue()
        let store = TestStore(initialState: DocumentRowReducer.State.testValue(
            document: document
        )) {
            DocumentRowReducer()
        }

        await store.send(.view(.rowTapped))
        await store.receive(\.delegate, .presentDocumentDetail(Shared(value: document)))
    }

    @Test
    func test_view_editButtonTapped() async throws {
        let document = Document.testValue()
        let store = TestStore(initialState: DocumentRowReducer.State.testValue(
            document: document
        )) {
            DocumentRowReducer()
        }

        await store.send(.view(.editButtonTapped)) {
            $0.destination = .documentForm(.testValue())
        }
    }

    @Test
    func test_view_previewButtonTapped_downloadSuccess() async throws {
        let data = try Data.testValue()
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("invoice.pdf")
        let store = TestStore(initialState: DocumentRowReducer.State.testValue()) {
            DocumentRowReducer()
        } withDependencies: {
            $0.downloadDocument.execute = { _, _ in data }
        }

        await store.send(.view(.previewButtonTapped)) {
            $0.isDownloading = true
        }
        await store.receive(\.downloadSucceeded) {
            $0.downloadedURL = url
            $0.isDownloading = false
            $0.quickLookPreview = url
        }
    }

    @Test
    func test_view_shareButtonTapped_downloadSuccess() async throws {
        let data = try Data.testValue()
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("invoice.pdf")
        let store = TestStore(initialState: DocumentRowReducer.State.testValue()) {
            DocumentRowReducer()
        } withDependencies: {
            $0.downloadDocument.execute = { _, _ in data }
        }

        await store.send(.view(.shareButtonTapped)) {
            $0.isDownloading = true
        }
        await store.receive(\.downloadSucceeded) {
            $0.downloadedURL = url
            $0.isDownloading = false
            $0.shareItem = ShareItem(url: url)
        }
    }

    @Test
    func test_view_shareButtonTapped_reusesDownloadedFile() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("invoice.pdf")
        let store = TestStore(initialState: DocumentRowReducer.State.testValue(
            downloadedURL: url
        )) {
            DocumentRowReducer()
        } withDependencies: {
            $0.downloadDocument.execute = { _, _ in
                Issue.record("The file is already on disk — it must not be downloaded again")
                return try Data.testValue()
            }
        }

        await store.send(.view(.shareButtonTapped)) {
            $0.shareItem = ShareItem(url: url)
        }
    }

    @Test
    func test_view_previewButtonTapped_downloadFailure() async throws {
        let toasts = LockIsolated<[Toast]>([])
        let store = TestStore(initialState: DocumentRowReducer.State.testValue()) {
            DocumentRowReducer()
        } withDependencies: {
            $0.downloadDocument.execute = { _, _ in throw ApiError.testValue() }
            $0.toastPresenter.present = { value in toasts.withValue { $0.append(value) } }
        }

        await store.send(.view(.previewButtonTapped)) {
            $0.isDownloading = true
        }
        await store.receive(\.downloadFailed) {
            $0.isDownloading = false
        }

        #expect(toasts.value == [.error("Something went wrong")])
    }
}
