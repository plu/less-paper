@testable import DocumentsFeature

import ApiInterface
import Components
import ComposableArchitecture
import Foundation
import Testing
import TestSupport

@MainActor
@Suite(
    .testDependencies()
)
struct DocumentHistoryReducerTests {

    @Test
    func test_view_onAppear_loadsHistory() async throws {
        let entries = [AuditLogEntry.testValue()]
        let store = TestStore(initialState: DocumentHistoryReducer.State.testValue()) {
            DocumentHistoryReducer()
        } withDependencies: {
            $0.getDocumentHistory.execute = { _, _ in entries }
        }

        await store.send(.view(.onAppear)) {
            $0.isLoading = true
        }
        await store.receive(\.historyResult) {
            $0.isLoading = false
            $0.entries = entries
        }
    }

    @Test
    func test_view_onAppear_passesTheDocumentIdAndServer() async throws {
        let received = LockIsolated<(id: Document.Id, server: Server)?>(nil)
        let server = Server.testValue(alias: "home")
        let store = TestStore(initialState: DocumentHistoryReducer.State.testValue(
            documentId: 42,
            server: server
        )) {
            DocumentHistoryReducer()
        } withDependencies: {
            $0.getDocumentHistory.execute = { id, server in
                received.setValue((id, server))
                return []
            }
        }

        await store.send(.view(.onAppear)) {
            $0.isLoading = true
        }
        await store.receive(\.historyResult) {
            $0.isLoading = false
            $0.entries = []
        }

        #expect(received.value?.id == 42)
        #expect(received.value?.server == server)
    }

    @Test
    func test_view_onAppear_alreadyLoaded_doesNotRefetch() async throws {
        let store = TestStore(
            initialState: DocumentHistoryReducer.State.testValue(entries: [.testValue()])
        ) {
            DocumentHistoryReducer()
        } withDependencies: {
            $0.getDocumentHistory.execute = { _, _ in
                Issue.record("History must load once per sheet, not on every return to the section.")
                return []
            }
        }

        await store.send(.view(.onAppear))
    }

    @Test
    func test_view_onAppear_afterFailure_doesNotRetrySilently() async throws {
        let store = TestStore(
            initialState: DocumentHistoryReducer.State.testValue(loadError: "Audit log is disabled")
        ) {
            DocumentHistoryReducer()
        }

        await store.send(.view(.onAppear))
    }

    @Test
    func test_view_onAppear_failure_setsLoadErrorAndToasts() async throws {
        let toasts = LockIsolated<[Toast]>([])
        let store = TestStore(initialState: DocumentHistoryReducer.State.testValue()) {
            DocumentHistoryReducer()
        } withDependencies: {
            $0.getDocumentHistory.execute = { _, _ in throw ApiError.testValue() }
            $0.toastPresenter.present = { value in
                toasts.withValue { $0.append(value) }
            }
        }

        await store.send(.view(.onAppear)) {
            $0.isLoading = true
        }
        await store.receive(\.historyResult) {
            $0.isLoading = false
            $0.loadError = ApiError.testValue().localizedDescription
        }

        #expect(toasts.value.count == 1)
    }

    @Test
    func test_view_retryLoadButtonTapped_clearsTheErrorAndRefetches() async throws {
        let entries = [AuditLogEntry.testValue()]
        let store = TestStore(
            initialState: DocumentHistoryReducer.State.testValue(loadError: "Audit log is disabled")
        ) {
            DocumentHistoryReducer()
        } withDependencies: {
            $0.getDocumentHistory.execute = { _, _ in entries }
        }

        await store.send(.view(.retryLoadButtonTapped)) {
            $0.isLoading = true
            $0.loadError = nil
        }
        await store.receive(\.historyResult) {
            $0.isLoading = false
            $0.entries = entries
        }
    }
}
