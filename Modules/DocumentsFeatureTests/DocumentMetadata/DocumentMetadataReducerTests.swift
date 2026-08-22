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
struct DocumentMetadataReducerTests {

    @Test
    func test_view_onAppear_loadsMetadata() async throws {
        let metadata = DocumentMetadata.testValue()
        let store = TestStore(initialState: DocumentMetadataReducer.State.testValue()) {
            DocumentMetadataReducer()
        } withDependencies: {
            $0.getDocumentMetadata.execute = { _, _ in metadata }
        }

        await store.send(.view(.onAppear)) {
            $0.isLoading = true
        }
        await store.receive(\.metadataResult) {
            $0.isLoading = false
            $0.metadata = metadata
        }
    }

    @Test
    func test_view_onAppear_passesTheDocumentIdAndServer() async throws {
        let received = LockIsolated<(id: Document.Id, server: Server)?>(nil)
        let server = Server.testValue(alias: "home")
        let store = TestStore(initialState: DocumentMetadataReducer.State.testValue(
            documentId: 42,
            server: server
        )) {
            DocumentMetadataReducer()
        } withDependencies: {
            $0.getDocumentMetadata.execute = { id, server in
                received.setValue((id, server))
                return .testValue()
            }
        }

        await store.send(.view(.onAppear)) {
            $0.isLoading = true
        }
        await store.receive(\.metadataResult) {
            $0.isLoading = false
            $0.metadata = .testValue()
        }

        #expect(received.value?.id == 42)
        #expect(received.value?.server == server)
    }

    @Test
    func test_view_onAppear_alreadyLoaded_doesNotRefetch() async throws {
        let store = TestStore(
            initialState: DocumentMetadataReducer.State.testValue(metadata: .testValue())
        ) {
            DocumentMetadataReducer()
        } withDependencies: {
            $0.getDocumentMetadata.execute = { _, _ in
                Issue.record("Metadata must load once per sheet, not on every return to the section.")
                return .testValue()
            }
        }

        await store.send(.view(.onAppear))
    }

    @Test
    func test_view_onAppear_afterFailure_doesNotRetrySilently() async throws {
        let store = TestStore(
            initialState: DocumentMetadataReducer.State.testValue(loadError: "The request timed out.")
        ) {
            DocumentMetadataReducer()
        } withDependencies: {
            $0.getDocumentMetadata.execute = { _, _ in
                Issue.record("A failed load is retried by the button, never silently.")
                return .testValue()
            }
        }

        await store.send(.view(.onAppear))
    }

    @Test
    func test_view_onAppear_failure_setsLoadErrorAndToasts() async throws {
        let toasts = LockIsolated<[Toast]>([])
        let store = TestStore(initialState: DocumentMetadataReducer.State.testValue()) {
            DocumentMetadataReducer()
        } withDependencies: {
            $0.getDocumentMetadata.execute = { _, _ in throw ApiError.testValue() }
            $0.toastPresenter.present = { value in
                toasts.withValue { $0.append(value) }
            }
        }

        await store.send(.view(.onAppear)) {
            $0.isLoading = true
        }
        await store.receive(\.metadataResult) {
            $0.isLoading = false
            $0.loadError = ApiError.testValue().localizedDescription
        }

        #expect(toasts.value.count == 1)
    }

    @Test
    func test_view_retryLoadButtonTapped_clearsTheErrorAndRefetches() async throws {
        let metadata = DocumentMetadata.testValue()
        let store = TestStore(
            initialState: DocumentMetadataReducer.State.testValue(loadError: "The request timed out.")
        ) {
            DocumentMetadataReducer()
        } withDependencies: {
            $0.getDocumentMetadata.execute = { _, _ in metadata }
        }

        await store.send(.view(.retryLoadButtonTapped)) {
            $0.isLoading = true
            $0.loadError = nil
        }
        await store.receive(\.metadataResult) {
            $0.isLoading = false
            $0.metadata = metadata
        }
    }

    @Test
    func test_view_retryLoadButtonTapped_whileLoading_isIgnored() async throws {
        let store = TestStore(
            initialState: DocumentMetadataReducer.State.testValue(isLoading: true)
        ) {
            DocumentMetadataReducer()
        } withDependencies: {
            $0.getDocumentMetadata.execute = { _, _ in
                Issue.record("A second tap must not start a second request.")
                return .testValue()
            }
        }

        await store.send(.view(.retryLoadButtonTapped))
    }
}
