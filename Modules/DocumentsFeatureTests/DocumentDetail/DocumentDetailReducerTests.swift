@testable import DocumentsFeature

import ApiInterface
import ComposableArchitecture
import Foundation
import Testing
import TestSupport

@MainActor
@Suite(
    .dependencies()
)
struct DocumentDetailReducerTests {

    @Test
    func test_destination_documentForm_delegate_documentUpdated() async throws {
        let store = TestStore(initialState: DocumentDetailReducer.State.testValue(
            destination: .documentForm(.testValue())
        )) {
            DocumentDetailReducer()
        }

        await store.send(.destination(.presented(.documentForm(.delegate(.documentUpdated(.testValue(title: "NEW TITLE"))))))) {
            $0.destination = nil
            $0.document = .testValue(title: "NEW TITLE")
        }
    }

    @Test
    func test_view_editDocumentButtonTapped() async throws {
        let store = TestStore(initialState: DocumentDetailReducer.State.testValue()) {
            DocumentDetailReducer()
        }

        await store.send(.view(.editDocumentButtonTapped)) {
            $0.destination = .documentForm(.testValue())
        }
    }

    @Test
    func test_view_onAppear_downloadSuccess() async throws {
        let downloadDocumentCalls = LockIsolated(0)
        let data = try Data.testValue()
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("invoice.pdf")
        let store = TestStore(initialState: DocumentDetailReducer.State.testValue()) {
            DocumentDetailReducer()
        } withDependencies: {
            $0.downloadDocument.execute = { _, _ in
                downloadDocumentCalls.withValue { $0 += 1 }
                return data
            }
        }

        await store.send(.view(.onAppear))
        await store.receive(\.downloadResult, .success(data: data, url: url)) {
            $0.downloadResult = .success(data: data, url: url)
        }
        await store.send(.view(.onAppear))
        #expect(downloadDocumentCalls.value == 1)
    }

    @Test
    func test_view_onAppear_downloadFailure() async throws {
        let store = TestStore(initialState: DocumentDetailReducer.State.testValue()) {
            DocumentDetailReducer()
        } withDependencies: {
            $0.downloadDocument.execute = { _, _ in throw ApiError.testValue() }
        }

        await store.send(.view(.onAppear))
        await store.receive(\.downloadResult, .failure("Something went wrong")) {
            $0.downloadResult = .failure("Something went wrong")
        }
    }

    @Test
    func test_view_previewButtonTapped() async throws {
        let data = try Data.testValue()
        let store = TestStore(initialState: DocumentDetailReducer.State.testValue(
            downloadResult: .success(data: data, url: .testValue())
        )) {
            DocumentDetailReducer()
        }

        await store.send(.view(.previewButtonTapped)) {
            $0.quickLookPreview = .testValue()
        }
    }

    @Test
    func test_view_retryDownloadButtonTapped_downloadSuccess() async throws {
        let data = try Data.testValue()
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("invoice.pdf")
        let store = TestStore(initialState: DocumentDetailReducer.State.testValue(
            downloadResult: .failure("error")
        )) {
            DocumentDetailReducer()
        } withDependencies: {
            $0.downloadDocument.execute = { _, _ in data }
        }

        await store.send(.view(.retryDownloadButtonTapped)) {
            $0.downloadResult = nil
        }
        await store.receive(\.downloadResult, .success(data: data, url: url)) {
            $0.downloadResult = .success(data: data, url: url)
        }
    }

    @Test
    func test_view_retryDownloadButtonTapped_downloadFailure() async throws {
        let store = TestStore(initialState: DocumentDetailReducer.State.testValue(
            downloadResult: .failure("error")
        )) {
            DocumentDetailReducer()
        } withDependencies: {
            $0.downloadDocument.execute = { _, _ in throw ApiError.testValue() }
        }

        await store.send(.view(.retryDownloadButtonTapped)) {
            $0.downloadResult = nil
        }
        await store.receive(\.downloadResult, .failure("Something went wrong")) {
            $0.downloadResult = .failure("Something went wrong")
        }
    }
}
