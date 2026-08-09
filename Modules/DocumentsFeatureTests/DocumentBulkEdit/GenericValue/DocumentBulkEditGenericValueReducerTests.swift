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
struct DocumentBulkEditGenericValueReducerTests {

    @Test
    func test_filteredValues() async throws {
        let store = TestStore(initialState: .testValue(
            searchText: "Off",
            values: [
                .testValue(id: 1, name: "Bank"),
                .testValue(id: 2, name: "Tax Office")
            ]
        )) {
            DocumentBulkEditGenericValueReducer<Correspondent>()
        }

        #expect(store.state.filteredValues == [.testValue(id: 2, name: "Tax Office")])
    }

    @Test
    func test_view_closeButtonTapped() async throws {
        var isDismissed = false
        let store = TestStore(initialState: .testValue()) {
            DocumentBulkEditGenericValueReducer<Correspondent>()
        } withDependencies: {
            $0.dismiss = .init { isDismissed = true }
        }

        await store.send(.view(.closeButtonTapped))
        #expect(isDismissed == true)
    }

    @Test
    func test_view_onAppear() async throws {
        let store = TestStore(initialState: .testValue()) {
            DocumentBulkEditGenericValueReducer<Correspondent>()
        } withDependencies: {
            $0.getSelectionData.execute = { _, _ in
                .testValue(selectedCorrespondents: [.init(documentCount: 2, id: 1)])
            }
        }

        await store.send(.view(.onAppear)) {
            $0.isLoading = true
        }
        await store.receive(\.selectionDataLoaded) {
            $0.documentCounts = [1: 2]
            $0.isLoading = false
        }
    }

    @Test
    func test_view_onAppear_error() async throws {
        let toasts = LockIsolated<[Toast]>([])
        let store = TestStore(initialState: .testValue()) {
            DocumentBulkEditGenericValueReducer<Correspondent>()
        } withDependencies: {
            $0.getSelectionData.execute = { _, _ in
                throw ApiError.testValue()
            }
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

    @Test
    func test_view_valueTapped_assignsWhenPartiallyApplied() async throws {
        let store = TestStore(initialState: .testValue(
            documentCounts: [1: 1],
            documents: [10, 11]
        )) {
            DocumentBulkEditGenericValueReducer<Correspondent>()
        }

        await store.send(.view(.valueTapped(.testValue(id: 1)))) {
            $0.operation = .assign(1)
        }
    }

    @Test
    func test_view_valueTapped_removesWhenAppliedToAll() async throws {
        let store = TestStore(initialState: .testValue(
            documentCounts: [1: 2],
            documents: [10, 11]
        )) {
            DocumentBulkEditGenericValueReducer<Correspondent>()
        }

        await store.send(.view(.valueTapped(.testValue(id: 1)))) {
            $0.operation = .remove
        }
    }

    @Test
    func test_view_valueTapped_reassignsToDifferentValue() async throws {
        let store = TestStore(initialState: .testValue(
            documentCounts: [1: 1],
            documents: [10, 11],
            operation: .assign(1)
        )) {
            DocumentBulkEditGenericValueReducer<Correspondent>()
        }

        await store.send(.view(.valueTapped(.testValue(id: 2)))) {
            $0.operation = .assign(2)
        }
    }

    @Test
    func test_view_valueTapped_togglesAssignedValueToRemove() async throws {
        let store = TestStore(initialState: .testValue(
            documentCounts: [1: 1],
            documents: [10, 11],
            operation: .assign(1)
        )) {
            DocumentBulkEditGenericValueReducer<Correspondent>()
        }

        await store.send(.view(.valueTapped(.testValue(id: 1)))) {
            $0.operation = .remove
        }
    }

    @Test
    func test_view_resetButtonTapped() async throws {
        let store = TestStore(initialState: .testValue(
            operation: .assign(1)
        )) {
            DocumentBulkEditGenericValueReducer<Correspondent>()
        }

        await store.send(.view(.resetButtonTapped)) {
            $0.operation = nil
        }
    }

    @Test
    func test_view_applyButtonTapped_confirmed() async throws {
        let message = LockIsolated<LocalizedStringResource?>(nil)
        let input = LockIsolated<BulkEditDocumentsInput?>(nil)
        let store = TestStore(initialState: .testValue(
            documents: [10, 11],
            operation: .assign(2)
        )) {
            DocumentBulkEditGenericValueReducer<Correspondent>()
        } withDependencies: {
            $0.documentBulkEditConfirmation.present = { value in
                message.setValue(value)
                return true
            }
            $0.bulkEditDocuments.execute = { bulkEditInput, _ in input.setValue(bulkEditInput) }
        }

        await store.send(.view(.applyButtonTapped))
        await store.receive(\.applyConfirmed) {
            $0.isSaving = true
        }
        await store.receive(\.delegate.documentsUpdated)

        #expect(message.value == .correspondentBulkEditConfirmationAssign("C2", 2))
        #expect(input.value?.method == .setCorrespondent(.init(correspondent: 2)))
    }

    @Test
    func test_view_applyButtonTapped_cancelled() async throws {
        let store = TestStore(initialState: .testValue(
            operation: .assign(1)
        )) {
            DocumentBulkEditGenericValueReducer<Correspondent>()
        } withDependencies: {
            $0.documentBulkEditConfirmation.present = { _ in false }
        }

        await store.send(.view(.applyButtonTapped))
    }

    @Test
    func test_view_applyButtonTapped_doesNothingWhenUnedited() async throws {
        let presentationCount = LockIsolated(0)
        let store = TestStore(initialState: .testValue()) {
            DocumentBulkEditGenericValueReducer<Correspondent>()
        } withDependencies: {
            $0.documentBulkEditConfirmation.present = { _ in
                presentationCount.setValue(presentationCount.value + 1)
                return false
            }
        }

        await store.send(.view(.applyButtonTapped))
        #expect(presentationCount.value == 0)
    }

    @Test
    func test_applyConfirmed_assign() async throws {
        let input = LockIsolated<BulkEditDocumentsInput?>(nil)
        let store = TestStore(initialState: .testValue(
            documents: [10, 11],
            operation: .assign(2)
        )) {
            DocumentBulkEditGenericValueReducer<Correspondent>()
        } withDependencies: {
            $0.bulkEditDocuments.execute = { bulkEditInput, _ in input.setValue(bulkEditInput) }
        }

        await store.send(.applyConfirmed) {
            $0.isSaving = true
        }
        await store.receive(\.delegate.documentsUpdated)

        let sent = try #require(input.value)
        #expect(sent.documents.sorted() == [10, 11])
        #expect(sent.method == .setCorrespondent(.init(correspondent: 2)))
    }

    @Test
    func test_applyConfirmed_remove() async throws {
        let input = LockIsolated<BulkEditDocumentsInput?>(nil)
        let store = TestStore(initialState: .testValue(
            documents: [10, 11],
            operation: .remove
        )) {
            DocumentBulkEditGenericValueReducer<Correspondent>()
        } withDependencies: {
            $0.bulkEditDocuments.execute = { bulkEditInput, _ in input.setValue(bulkEditInput) }
        }

        await store.send(.applyConfirmed) {
            $0.isSaving = true
        }
        await store.receive(\.delegate.documentsUpdated)

        let sent = try #require(input.value)
        #expect(sent.method == .setCorrespondent(.init(correspondent: nil)))
    }

    @Test
    func test_applyConfirmed_error() async throws {
        let toasts = LockIsolated<[Toast]>([])
        let store = TestStore(initialState: .testValue(
            operation: .assign(1)
        )) {
            DocumentBulkEditGenericValueReducer<Correspondent>()
        } withDependencies: {
            $0.bulkEditDocuments.execute = { _, _ in
                throw ApiError.testValue()
            }
            $0.toastPresenter.present = { value in
                toasts.withValue { $0.append(value) }
            }
        }

        await store.send(.applyConfirmed) {
            $0.isSaving = true
        }
        await store.receive(\.error) {
            $0.isSaving = false
        }
        #expect(toasts.value == [.error("Something went wrong")])
    }

    @Test
    func test_confirmationMessage() async throws {
        let assign = DocumentBulkEditGenericValueReducer<Correspondent>.State.testValue(
            documents: [10, 11],
            operation: .assign(1)
        )
        #expect(assign.confirmationMessage == .correspondentBulkEditConfirmationAssign("C1", 2))

        let remove = DocumentBulkEditGenericValueReducer<Correspondent>.State.testValue(
            documents: [10, 11],
            operation: .remove
        )
        #expect(remove.confirmationMessage == .correspondentBulkEditConfirmationRemove(2))

        let unedited = DocumentBulkEditGenericValueReducer<Correspondent>.State.testValue()
        #expect(unedited.confirmationMessage == nil)
    }

    @Test
    func test_systemImage() async throws {
        let state = DocumentBulkEditGenericValueReducer<Correspondent>.State.testValue(
            documentCounts: [1: 2, 2: 1],
            documents: [10, 11]
        )

        #expect(state.systemImage(for: .testValue(id: 1)) == "checkmark.circle.fill")
        #expect(state.systemImage(for: .testValue(id: 2)) == "minus.circle")
        #expect(state.systemImage(for: .testValue(id: 3)) == "circle")
    }

    @Test
    func test_systemImage_whenEdited() async throws {
        let state = DocumentBulkEditGenericValueReducer<Correspondent>.State.testValue(
            documentCounts: [1: 2, 2: 1],
            documents: [10, 11],
            operation: .assign(2)
        )

        #expect(state.systemImage(for: .testValue(id: 1)) == "circle")
        #expect(state.systemImage(for: .testValue(id: 2)) == "checkmark.circle.fill")
    }
}
