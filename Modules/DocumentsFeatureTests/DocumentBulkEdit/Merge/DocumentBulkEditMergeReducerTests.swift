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
struct DocumentBulkEditMergeReducerTests {

    @Test
    func test_canMerge() async throws {
        #expect(DocumentBulkEditMergeReducer.State.testValue(documents: []).canMerge == false)
        #expect(DocumentBulkEditMergeReducer.State.testValue(
            documents: [.testValue(id: 1)]
        ).canMerge == false)
        #expect(DocumentBulkEditMergeReducer.State.testValue(
            documents: [.testValue(id: 1), .testValue(id: 2)]
        ).canMerge == true)
    }

    @Test
    func test_onAppear_loadsDocumentsInListOrder() async throws {
        let store = TestStore(initialState: .testValue(
            documents: [],
            selectedDocuments: [2, 1],
            sort: .init(direction: .ascending, field: .title)
        )) {
            DocumentBulkEditMergeReducer()
        } withDependencies: {
            $0.getDocumentsByIds.execute = { input, _ in
                #expect(input.ids == [1, 2])
                #expect(input.sortDirection == .ascending)
                #expect(input.sortField == .title)
                return [.testValue(id: 2, title: "A"), .testValue(id: 1, title: "B")]
            }
        }

        await store.send(.view(.onAppear)) {
            $0.isLoading = true
        }
        await store.receive(\.documentsLoaded) {
            $0.documents = [.testValue(id: 2, title: "A"), .testValue(id: 1, title: "B")]
            $0.isLoading = false
        }
    }

    @Test
    func test_onAppear_doesNotReloadWhenAlreadyLoaded() async throws {
        let store = TestStore(initialState: .testValue(
            documents: [.testValue(id: 1), .testValue(id: 2)]
        )) {
            DocumentBulkEditMergeReducer()
        }

        await store.send(.view(.onAppear))
    }

    @Test
    func test_moved_reordersDocuments() async throws {
        let store = TestStore(initialState: .testValue(
            documents: [.testValue(id: 1), .testValue(id: 2), .testValue(id: 3)]
        )) {
            DocumentBulkEditMergeReducer()
        }

        await store.send(.view(.moved(IndexSet(integer: 2), 0))) {
            $0.documents = [.testValue(id: 3), .testValue(id: 1), .testValue(id: 2)]
        }
    }

    @Test
    func test_merge_sendsReorderedIds() async throws {
        let store = TestStore(initialState: .testValue(
            deleteOriginals: true,
            documents: [.testValue(id: 3), .testValue(id: 1), .testValue(id: 2)]
        )) {
            DocumentBulkEditMergeReducer()
        } withDependencies: {
            $0.documentBulkEditConfirmation.presentMerge = { deleteOriginals, documentCount in
                #expect(deleteOriginals == true)
                #expect(documentCount == 3)
                return true
            }
            $0.bulkEditDocuments.execute = { input, _ in
                #expect(input.documents == [3, 1, 2])
                #expect(input.method == .merge(.init(archiveFallback: true, deleteOriginals: true)))
            }
        }

        await store.send(.view(.mergeButtonTapped))
        await store.receive(\.mergeConfirmed) {
            $0.isSaving = true
        }
        await store.receive(\.delegate.documentsMerged)
    }

    @Test
    func test_merge_whenConfirmationCancelled() async throws {
        let store = TestStore(initialState: .testValue(
            documents: [.testValue(id: 1), .testValue(id: 2)]
        )) {
            DocumentBulkEditMergeReducer()
        } withDependencies: {
            $0.documentBulkEditConfirmation.presentMerge = { _, _ in false }
        }

        await store.send(.view(.mergeButtonTapped))
    }

    @Test
    func test_merge_whenBelowTwoDocuments() async throws {
        let store = TestStore(initialState: .testValue(
            documents: [.testValue(id: 1)]
        )) {
            DocumentBulkEditMergeReducer()
        }

        await store.send(.view(.mergeButtonTapped))
    }

    @Test
    func test_merge_whenRequestFails() async throws {
        let toasts = LockIsolated<[Toast]>([])
        let store = TestStore(initialState: .testValue(
            documents: [.testValue(id: 1), .testValue(id: 2)]
        )) {
            DocumentBulkEditMergeReducer()
        } withDependencies: {
            $0.documentBulkEditConfirmation.presentMerge = { _, _ in true }
            $0.bulkEditDocuments.execute = { _, _ in throw ApiError.testValue() }
            $0.toastPresenter.present = { value in
                toasts.withValue { $0.append(value) }
            }
        }

        await store.send(.view(.mergeButtonTapped))
        await store.receive(\.mergeConfirmed) {
            $0.isSaving = true
        }
        await store.receive(\.error) {
            $0.isSaving = false
        }
        #expect(toasts.value == [.error("Something went wrong")])
    }

    @Test
    func test_onAppear_whenRequestFails() async throws {
        let toasts = LockIsolated<[Toast]>([])
        let store = TestStore(initialState: .testValue(documents: [])) {
            DocumentBulkEditMergeReducer()
        } withDependencies: {
            $0.getDocumentsByIds.execute = { _, _ in throw ApiError.testValue() }
            $0.toastPresenter.present = { value in
                toasts.withValue { $0.append(value) }
            }
        }

        await store.send(.view(.onAppear)) {
            $0.isLoading = true
        }
        await store.receive(\.error) {
            $0.isLoading = false
        }
        #expect(toasts.value == [.error("Something went wrong")])
    }
}
