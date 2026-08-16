@testable import DocumentsFeature

import ApiInterface
import Components
import ComposableArchitecture
import Foundation
import Testing
import TestSupport

@MainActor
@Suite(
    .dependencies {
        $0.apiCache.correspondent = { id, _ in id == 1 ? .testValue(id: 1, name: "Stadtwerke") : nil }
    }
)
struct DocumentBulkEditTitleReducerTests {

    @Test
    func test_previews_expandTheTemplate() async throws {
        let state = DocumentBulkEditTitleReducer.State.testValue(
            loadedDocuments: [
                .testValue(correspondent: 1, id: 10, title: "Old A"),
                .testValue(correspondent: nil, id: 11, title: "Old B")
            ],
            template: "{correspondent}-{doc_pk}"
        )

        #expect(state.previews.map(\.oldTitle) == ["Old A", "Old B"])
        #expect(state.previews.map(\.newTitle) == ["Stadtwerke-10", "-11"])
    }

    @Test
    func test_changedPreviews_skipUnchangedAndEmptyTitles() async throws {
        let state = DocumentBulkEditTitleReducer.State.testValue(
            loadedDocuments: [
                .testValue(id: 10, title: "Keep"),
                .testValue(id: 11, title: "Change")
            ],
            template: "Keep"
        )

        #expect(state.changedPreviews.map(\.id) == [11])

        let empty = DocumentBulkEditTitleReducer.State.testValue(
            loadedDocuments: [.testValue(correspondent: nil, id: 10, title: "Keep")],
            template: "{correspondent}"
        )

        #expect(empty.changedPreviews.isEmpty)
    }

    @Test
    func test_isEdited() async throws {
        #expect(DocumentBulkEditTitleReducer.State.testValue().isEdited == false)
        #expect(
            DocumentBulkEditTitleReducer.State.testValue(
                loadedDocuments: [.testValue(id: 10, title: "Old")],
                template: "New"
            ).isEdited == true
        )
    }

    @Test
    func test_view_onAppear_loadsSelectionInChunks() async throws {
        let requested = LockIsolated<[[Document.Id]]>([])
        let store = TestStore(initialState: .testValue(
            documents: [10, 11],
            loadedDocuments: []
        )) {
            DocumentBulkEditTitleReducer()
        } withDependencies: {
            $0.getDocumentsByIds.execute = { input, _ in
                requested.withValue { $0.append(input.ids) }
                return input.ids.map { .testValue(id: $0, title: "Doc \($0)") }
            }
        }

        await store.send(.view(.onAppear)) {
            $0.isLoading = true
        }
        await store.receive(\.documentsLoaded) {
            $0.loadedDocuments = [
                .testValue(id: 10, title: "Doc 10"),
                .testValue(id: 11, title: "Doc 11")
            ]
        }
        await store.receive(\.documentsLoadFinished) {
            $0.isLoading = false
        }

        #expect(requested.value == [[10, 11]])
    }

    @Test
    func test_view_onAppear_error() async throws {
        let toasts = LockIsolated<[Toast]>([])
        let store = TestStore(initialState: .testValue(documents: [10])) {
            DocumentBulkEditTitleReducer()
        } withDependencies: {
            $0.getDocumentsByIds.execute = { _, _ in throw ApiError.testValue() }
            $0.toastPresenter.present = { value in toasts.withValue { $0.append(value) } }
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
    func test_view_placeholderTapped_appendsToken() async throws {
        let store = TestStore(initialState: .testValue(template: "Scan-")) {
            DocumentBulkEditTitleReducer()
        }

        await store.send(.view(.placeholderTapped(.createdYear))) {
            $0.template = "Scan-{created_year}"
        }
    }

    @Test
    func test_view_resetButtonTapped() async throws {
        let store = TestStore(initialState: .testValue(template: "Scan-{title}")) {
            DocumentBulkEditTitleReducer()
        }

        // Back to the template the sheet opens with, not to a blank one: a blank template renames
        // nothing, so it would be a state the user cannot apply and cannot get out of except by
        // retyping `{title}`.
        await store.send(.view(.resetButtonTapped)) {
            $0.template = "{title}"
        }
    }

    @Test
    func test_template_startsAsTheDocumentTitle() async throws {
        let state = DocumentBulkEditTitleReducer.State(
            documents: [10],
            server: .testValue()
        )

        #expect(state.template == "{title}")
    }

    @Test
    func test_isEdited_isFalseForTheStartingTemplate() async throws {
        let state = DocumentBulkEditTitleReducer.State.testValue(
            loadedDocuments: [.testValue(id: 10, title: "Invoice")]
        )

        #expect(state.previews.map(\.newTitle) == ["Invoice"])
        #expect(state.isEdited == false)
    }

    @Test
    func test_view_closeButtonTapped() async throws {
        var isDismissed = false
        let store = TestStore(initialState: .testValue()) {
            DocumentBulkEditTitleReducer()
        } withDependencies: {
            $0.dismiss = .init { isDismissed = true }
        }

        await store.send(.view(.closeButtonTapped))
        #expect(isDismissed == true)
    }

    @Test
    func test_view_applyButtonTapped_confirmed() async throws {
        let documentCount = LockIsolated(0)
        let updates = LockIsolated<[Document.Id: String]>([:])
        let store = TestStore(initialState: .testValue(
            loadedDocuments: [
                .testValue(id: 10, title: "Old A"),
                .testValue(id: 11, title: "Old B")
            ],
            template: "Renamed-{doc_pk}"
        )) {
            DocumentBulkEditTitleReducer()
        } withDependencies: {
            $0.documentBulkEditConfirmation.presentTitle = { count in
                documentCount.setValue(count)
                return true
            }
            $0.updateDocument.execute = { id, input, _ in
                updates.withValue { $0[id] = input.title }
                return .testValue(id: id, title: input.title)
            }
        }

        await store.send(.view(.applyButtonTapped))
        await store.receive(\.applyConfirmed) {
            $0.isSaving = true
        }
        await store.receive(\.progress) {
            $0.savedCount = 1
        }
        await store.receive(\.progress) {
            $0.savedCount = 2
        }
        await store.receive(\.saved) {
            $0.isSaving = false
        }
        await store.receive(\.delegate.documentsUpdated)

        #expect(documentCount.value == 2)
        #expect(updates.value == [10: "Renamed-10", 11: "Renamed-11"])
    }

    @Test
    func test_view_applyButtonTapped_cancelled() async throws {
        let store = TestStore(initialState: .testValue(
            loadedDocuments: [.testValue(id: 10, title: "Old")],
            template: "New"
        )) {
            DocumentBulkEditTitleReducer()
        } withDependencies: {
            $0.documentBulkEditConfirmation.presentTitle = { _ in false }
        }

        await store.send(.view(.applyButtonTapped))
    }

    @Test
    func test_view_applyButtonTapped_doesNothingWhenNothingChanges() async throws {
        let presentationCount = LockIsolated(0)
        let store = TestStore(initialState: .testValue(
            loadedDocuments: [.testValue(id: 10, title: "Same")],
            template: "Same"
        )) {
            DocumentBulkEditTitleReducer()
        } withDependencies: {
            $0.documentBulkEditConfirmation.presentTitle = { _ in
                presentationCount.setValue(presentationCount.value + 1)
                return false
            }
        }

        await store.send(.view(.applyButtonTapped))
        #expect(presentationCount.value == 0)
    }

    @Test
    func test_applyConfirmed_skipsUnchangedDocuments() async throws {
        let updated = LockIsolated<[Document.Id]>([])
        let store = TestStore(initialState: .testValue(
            loadedDocuments: [
                .testValue(id: 10, title: "Renamed-10"),
                .testValue(id: 11, title: "Old B")
            ],
            template: "Renamed-{doc_pk}"
        )) {
            DocumentBulkEditTitleReducer()
        } withDependencies: {
            $0.updateDocument.execute = { id, input, _ in
                updated.withValue { $0.append(id) }
                return .testValue(id: id, title: input.title)
            }
        }

        await store.send(.applyConfirmed) {
            $0.isSaving = true
        }
        await store.receive(\.progress) {
            $0.savedCount = 1
        }
        await store.receive(\.saved) {
            $0.isSaving = false
        }
        await store.receive(\.delegate.documentsUpdated)

        #expect(updated.value == [11])
    }

    @Test
    func test_applyConfirmed_dismissesOnFullSuccess() async throws {
        var isDismissed = false
        let store = TestStore(initialState: .testValue(
            loadedDocuments: [.testValue(id: 10, title: "Old")],
            template: "New"
        )) {
            DocumentBulkEditTitleReducer()
        } withDependencies: {
            $0.dismiss = .init { isDismissed = true }
            $0.updateDocument.execute = { id, input, _ in .testValue(id: id, title: input.title) }
        }

        await store.send(.applyConfirmed) {
            $0.isSaving = true
        }
        await store.receive(\.progress) {
            $0.savedCount = 1
        }
        await store.receive(\.saved) {
            $0.isSaving = false
        }
        await store.receive(\.delegate.documentsUpdated, .init([10]))

        #expect(isDismissed == true)
    }

    @Test
    func test_applyConfirmed_partialFailureKeepsOnlyFailures() async throws {
        var isDismissed = false
        let toasts = LockIsolated<[Toast]>([])
        let store = TestStore(initialState: .testValue(
            loadedDocuments: [
                .testValue(id: 10, title: "Old A"),
                .testValue(id: 11, title: "Old B")
            ],
            template: "Renamed-{doc_pk}"
        )) {
            DocumentBulkEditTitleReducer()
        } withDependencies: {
            $0.dismiss = .init { isDismissed = true }
            $0.toastPresenter.present = { value in toasts.withValue { $0.append(value) } }
            $0.updateDocument.execute = { id, input, _ in
                if id == 11 {
                    throw ApiError.testValue()
                }
                return .testValue(id: id, title: input.title)
            }
        }

        await store.send(.applyConfirmed) {
            $0.isSaving = true
        }
        await store.receive(\.progress) {
            $0.savedCount = 1
        }
        await store.receive(\.progress) {
            $0.savedCount = 2
        }
        await store.receive(\.saved) {
            $0.isSaving = false
            $0.loadedDocuments = [.testValue(id: 11, title: "Old B")]
            $0.savedCount = 0
        }
        await store.receive(\.delegate.documentsUpdated, .init([10]))

        #expect(isDismissed == false)
        #expect(toasts.value == [
            .error("There was one document that could not be updated. You can just try again to update it.")
        ])
    }
}
