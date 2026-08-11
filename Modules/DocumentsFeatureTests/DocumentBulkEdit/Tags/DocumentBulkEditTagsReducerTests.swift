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
struct DocumentBulkEditTagsReducerTests {

    @Test
    func test_filteredValues() async throws {
        let store = TestStore(initialState: .testValue(
            searchText: "voi",
            values: [
                .testValue(id: 1, name: "Invoice"),
                .testValue(id: 2, name: "Receipt")
            ]
        )) {
            DocumentBulkEditTagsReducer()
        }

        #expect(store.state.filteredValues == [.testValue(id: 1, name: "Invoice")])
    }

    @Test
    func test_isEdited() async throws {
        #expect(DocumentBulkEditTagsReducer.State.testValue().isEdited == false)
        #expect(DocumentBulkEditTagsReducer.State.testValue(operations: [1: .add]).isEdited == true)
        #expect(DocumentBulkEditTagsReducer.State.testValue(operations: [1: .remove]).isEdited == true)
    }

    @Test
    func test_addTags_removeTags_areSorted() async throws {
        let state = DocumentBulkEditTagsReducer.State.testValue(
            operations: [3: .add, 1: .add, 4: .remove, 2: .remove]
        )

        #expect(state.addTags == [1, 3])
        #expect(state.removeTags == [2, 4])
    }

    @Test
    func test_systemImage() async throws {
        let state = DocumentBulkEditTagsReducer.State.testValue(
            documentCounts: [1: 2, 2: 1],
            documents: [10, 11]
        )

        #expect(state.systemImage(for: .testValue(id: 1)) == "checkmark.circle.fill")
        #expect(state.systemImage(for: .testValue(id: 2)) == "minus.circle")
        #expect(state.systemImage(for: .testValue(id: 3)) == "circle")
    }

    @Test
    func test_systemImage_whenEdited() async throws {
        let state = DocumentBulkEditTagsReducer.State.testValue(
            documentCounts: [1: 2, 2: 1],
            documents: [10, 11],
            operations: [1: .remove, 2: .add]
        )

        #expect(state.systemImage(for: .testValue(id: 1)) == "circle")
        #expect(state.systemImage(for: .testValue(id: 2)) == "checkmark.circle.fill")
    }

    @Test
    func test_systemImage_withEmptySelection() async throws {
        let state = DocumentBulkEditTagsReducer.State.testValue(
            documentCounts: [:],
            documents: []
        )

        #expect(state.systemImage(for: .testValue(id: 1)) == "circle")
    }

    @Test
    func test_view_valueTapped_cyclesWhenUnassigned() async throws {
        let store = TestStore(initialState: .testValue(
            documentCounts: [:],
            documents: [10, 11]
        )) {
            DocumentBulkEditTagsReducer()
        }

        await store.send(.view(.valueTapped(.testValue(id: 1)))) {
            $0.operations = [1: .add]
        }
        await store.send(.view(.valueTapped(.testValue(id: 1)))) {
            $0.operations = [:]
        }
    }

    @Test
    func test_view_valueTapped_cyclesWhenPartiallyAssigned() async throws {
        let store = TestStore(initialState: .testValue(
            documentCounts: [1: 1],
            documents: [10, 11]
        )) {
            DocumentBulkEditTagsReducer()
        }

        await store.send(.view(.valueTapped(.testValue(id: 1)))) {
            $0.operations = [1: .add]
        }
        await store.send(.view(.valueTapped(.testValue(id: 1)))) {
            $0.operations = [1: .remove]
        }
        await store.send(.view(.valueTapped(.testValue(id: 1)))) {
            $0.operations = [:]
        }
    }

    @Test
    func test_view_valueTapped_cyclesWhenAssignedToAll() async throws {
        let store = TestStore(initialState: .testValue(
            documentCounts: [1: 2],
            documents: [10, 11]
        )) {
            DocumentBulkEditTagsReducer()
        }

        await store.send(.view(.valueTapped(.testValue(id: 1)))) {
            $0.operations = [1: .remove]
        }
        await store.send(.view(.valueTapped(.testValue(id: 1)))) {
            $0.operations = [:]
        }
    }

    @Test
    func test_view_valueTapped_tracksTagsIndependently() async throws {
        let store = TestStore(initialState: .testValue(
            documentCounts: [1: 2],
            documents: [10, 11]
        )) {
            DocumentBulkEditTagsReducer()
        }

        await store.send(.view(.valueTapped(.testValue(id: 1)))) {
            $0.operations = [1: .remove]
        }
        await store.send(.view(.valueTapped(.testValue(id: 2)))) {
            $0.operations = [1: .remove, 2: .add]
        }
    }

    @Test
    func test_view_resetButtonTapped() async throws {
        let store = TestStore(initialState: .testValue(
            operations: [1: .add, 2: .remove]
        )) {
            DocumentBulkEditTagsReducer()
        }

        await store.send(.view(.resetButtonTapped)) {
            $0.operations = [:]
        }
    }

    @Test
    func test_view_onAppear() async throws {
        let store = TestStore(initialState: .testValue()) {
            DocumentBulkEditTagsReducer()
        } withDependencies: {
            $0.getSelectionData.execute = { _, _ in
                .testValue(selectedTags: [
                    .init(documentCount: 2, id: 1),
                    .init(documentCount: 1, id: 2)
                ])
            }
        }

        await store.send(.view(.onAppear)) {
            $0.isLoading = true
        }
        await store.receive(\.selectionDataLoaded) {
            $0.documentCounts = [1: 2, 2: 1]
            $0.isLoading = false
        }
    }

    @Test
    func test_view_onAppear_sendsSelectedDocuments() async throws {
        let input = LockIsolated<GetSelectionDataInput?>(nil)
        let store = TestStore(initialState: .testValue(
            documents: [10, 11]
        )) {
            DocumentBulkEditTagsReducer()
        } withDependencies: {
            $0.getSelectionData.execute = { selectionDataInput, _ in
                input.setValue(selectionDataInput)
                return .testValue(selectedTags: [])
            }
        }

        await store.send(.view(.onAppear)) {
            $0.isLoading = true
        }
        await store.receive(\.selectionDataLoaded) {
            $0.documentCounts = [:]
            $0.isLoading = false
        }

        #expect(input.value?.documents.sorted() == [10, 11])
    }

    @Test
    func test_view_onAppear_error() async throws {
        let toasts = LockIsolated<[Toast]>([])
        let store = TestStore(initialState: .testValue()) {
            DocumentBulkEditTagsReducer()
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
    func test_view_applyButtonTapped_confirmed() async throws {
        let addTags = LockIsolated<[ApiInterface.Tag]>([])
        let documentCount = LockIsolated(0)
        let removeTags = LockIsolated<[ApiInterface.Tag]>([])
        let input = LockIsolated<BulkEditDocumentsInput?>(nil)
        let store = TestStore(initialState: .testValue(
            documents: [10, 11],
            operations: [2: .add, 1: .remove],
            values: [
                .testValue(id: 1, name: "Zebra"),
                .testValue(id: 2, name: "Apple")
            ]
        )) {
            DocumentBulkEditTagsReducer()
        } withDependencies: {
            $0.documentBulkEditConfirmation.presentTags = { add, count, remove in
                addTags.setValue(add)
                documentCount.setValue(count)
                removeTags.setValue(remove)
                return true
            }
            $0.bulkEditDocuments.execute = { bulkEditInput, _ in input.setValue(bulkEditInput) }
        }

        await store.send(.view(.applyButtonTapped))
        await store.receive(\.applyConfirmed) {
            $0.isSaving = true
        }
        await store.receive(\.delegate.documentsUpdated)

        #expect(addTags.value.map(\.id) == [2])
        #expect(documentCount.value == 2)
        #expect(removeTags.value.map(\.id) == [1])

        let sent = try #require(input.value)
        #expect(sent.documents.sorted() == [10, 11])
        #expect(sent.method == .modifyTags(.init(addTags: [2], removeTags: [1])))
    }

    @Test
    func test_view_applyButtonTapped_sortsTagsByName() async throws {
        let addTags = LockIsolated<[ApiInterface.Tag]>([])
        let store = TestStore(initialState: .testValue(
            operations: [1: .add, 2: .add],
            values: [
                .testValue(id: 1, name: "Zebra"),
                .testValue(id: 2, name: "Apple")
            ]
        )) {
            DocumentBulkEditTagsReducer()
        } withDependencies: {
            $0.documentBulkEditConfirmation.presentTags = { add, _, _ in
                addTags.setValue(add)
                return false
            }
        }

        await store.send(.view(.applyButtonTapped))

        #expect(addTags.value.map(\.name) == ["Apple", "Zebra"])
    }

    @Test
    func test_view_applyButtonTapped_cancelled() async throws {
        let store = TestStore(initialState: .testValue(
            operations: [1: .add]
        )) {
            DocumentBulkEditTagsReducer()
        } withDependencies: {
            $0.documentBulkEditConfirmation.presentTags = { _, _, _ in false }
        }

        await store.send(.view(.applyButtonTapped))
    }

    @Test
    func test_view_applyButtonTapped_doesNothingWhenUnedited() async throws {
        let presentationCount = LockIsolated(0)
        let store = TestStore(initialState: .testValue()) {
            DocumentBulkEditTagsReducer()
        } withDependencies: {
            $0.documentBulkEditConfirmation.presentTags = { _, _, _ in
                presentationCount.setValue(presentationCount.value + 1)
                return false
            }
        }

        await store.send(.view(.applyButtonTapped))
        #expect(presentationCount.value == 0)
    }

    @Test
    func test_applyConfirmed_addOnly() async throws {
        let input = LockIsolated<BulkEditDocumentsInput?>(nil)
        let store = TestStore(initialState: .testValue(
            documents: [10, 11],
            operations: [2: .add, 1: .add]
        )) {
            DocumentBulkEditTagsReducer()
        } withDependencies: {
            $0.bulkEditDocuments.execute = { bulkEditInput, _ in input.setValue(bulkEditInput) }
        }

        await store.send(.applyConfirmed) {
            $0.isSaving = true
        }
        await store.receive(\.delegate.documentsUpdated)

        let sent = try #require(input.value)
        #expect(sent.method == .modifyTags(.init(addTags: [1, 2], removeTags: [])))
    }

    @Test
    func test_applyConfirmed_error() async throws {
        let toasts = LockIsolated<[Toast]>([])
        let store = TestStore(initialState: .testValue(
            operations: [1: .add]
        )) {
            DocumentBulkEditTagsReducer()
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
    func test_view_closeButtonTapped() async throws {
        var isDismissed = false
        let store = TestStore(initialState: .testValue()) {
            DocumentBulkEditTagsReducer()
        } withDependencies: {
            $0.dismiss = .init { isDismissed = true }
        }

        await store.send(.view(.closeButtonTapped))
        #expect(isDismissed == true)
    }
}
