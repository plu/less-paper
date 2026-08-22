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
struct DocumentNotesReducerTests {

    @Test
    func test_view_onAppear_loadsNotes() async throws {
        let notes = [Note.testValue()]
        let store = TestStore(initialState: DocumentNotesReducer.State.testValue()) {
            DocumentNotesReducer()
        } withDependencies: {
            $0.getNotes.execute = { _, _ in notes }
        }

        await store.send(.view(.onAppear)) {
            $0.isLoading = true
        }
        await store.receive(\.notesResult) {
            $0.isLoading = false
            $0.notes = IdentifiedArray(uniqueElements: notes)
        }
    }

    @Test
    func test_view_onAppear_alreadyLoaded_doesNotRefetch() async throws {
        let store = TestStore(
            initialState: DocumentNotesReducer.State.testValue(notes: [.testValue()])
        ) {
            DocumentNotesReducer()
        } withDependencies: {
            $0.getNotes.execute = { _, _ in
                Issue.record("Notes must load once per sheet, not on every return to the section.")
                return []
            }
        }

        await store.send(.view(.onAppear))
    }

    @Test
    func test_view_onAppear_emptyResult_doesNotRefetch() async throws {
        // The distinction nil draws from [] is the whole reason notes is optional: a document with
        // no notes is loaded, and must not be re-requested every time the section reappears.
        let store = TestStore(initialState: DocumentNotesReducer.State.testValue(notes: [])) {
            DocumentNotesReducer()
        } withDependencies: {
            $0.getNotes.execute = { _, _ in
                Issue.record("An empty list is a loaded list.")
                return []
            }
        }

        await store.send(.view(.onAppear))
    }

    @Test
    func test_view_onAppear_afterFailure_doesNotRetrySilently() async throws {
        let store = TestStore(
            initialState: DocumentNotesReducer.State.testValue(loadError: "The request timed out.")
        ) {
            DocumentNotesReducer()
        } withDependencies: {
            $0.getNotes.execute = { _, _ in
                Issue.record("A failed load is retried by the button, never silently.")
                return []
            }
        }

        await store.send(.view(.onAppear))
    }

    @Test
    func test_view_onAppear_failure_setsLoadError() async throws {
        let toasts = LockIsolated<[Toast]>([])
        let store = TestStore(initialState: DocumentNotesReducer.State.testValue()) {
            DocumentNotesReducer()
        } withDependencies: {
            $0.getNotes.execute = { _, _ in throw TestError.someError }
            $0.toastPresenter.present = { value in
                toasts.withValue { $0.append(value) }
            }
        }

        await store.send(.view(.onAppear)) {
            $0.isLoading = true
        }
        await store.receive(\.notesResult) {
            $0.isLoading = false
            $0.loadError = TestError.someError.localizedDescription
        }
        #expect(toasts.value == [.error(TestError.someError.localizedDescription)])
    }

    @Test
    func test_view_retryLoadButtonTapped_clearsErrorAndLoads() async throws {
        let notes = [Note.testValue()]
        let store = TestStore(
            initialState: DocumentNotesReducer.State.testValue(loadError: "The request timed out.")
        ) {
            DocumentNotesReducer()
        } withDependencies: {
            $0.getNotes.execute = { _, _ in notes }
        }

        await store.send(.view(.retryLoadButtonTapped)) {
            $0.isLoading = true
            $0.loadError = nil
        }
        await store.receive(\.notesResult) {
            $0.isLoading = false
            $0.notes = IdentifiedArray(uniqueElements: notes)
        }
    }

    @Test(arguments: ["", " ", "\n", "   \n  "])
    func test_canCreate_isFalseForBlankDrafts(draft: String) async throws {
        // The server accepts an empty note with a 200, so this guard is the only thing standing
        // between a stray tap and a blank row on the document.
        let state = DocumentNotesReducer.State.testValue(draft: draft)

        #expect(!state.canCreate)
    }

    @Test
    func test_canCreate_isFalseWhileCreating() async throws {
        let state = DocumentNotesReducer.State.testValue(draft: "Needs a signature", isCreating: true)

        #expect(!state.canCreate)
    }

    @Test
    func test_view_addButtonTapped_blankDraft_doesNothing() async throws {
        let store = TestStore(initialState: DocumentNotesReducer.State.testValue(draft: "   ")) {
            DocumentNotesReducer()
        } withDependencies: {
            $0.createNote.execute = { _, _, _ in
                Issue.record("A blank note must never reach the server.")
                return []
            }
        }

        await store.send(.view(.addButtonTapped))
    }

    @Test
    func test_view_addButtonTapped_trimsAndClearsDraft() async throws {
        let created = [Note.testValue(), Note.testValue(id: 2, note: "Filed under Q3")]
        let store = TestStore(
            initialState: DocumentNotesReducer.State.testValue(draft: "  Filed under Q3  ")
        ) {
            DocumentNotesReducer()
        } withDependencies: {
            $0.createNote.execute = { _, input, _ in
                #expect(input.note == "Filed under Q3")
                return created
            }
        }

        await store.send(.view(.addButtonTapped)) {
            $0.isCreating = true
        }
        await store.receive(\.notesResult) {
            $0.isCreating = false
            $0.draft = ""
            $0.notes = IdentifiedArray(uniqueElements: created)
        }
    }

    @Test
    func test_view_addButtonTapped_failure_keepsDraft() async throws {
        let toasts = LockIsolated<[Toast]>([])
        let store = TestStore(
            initialState: DocumentNotesReducer.State.testValue(draft: "Filed under Q3", notes: [])
        ) {
            DocumentNotesReducer()
        } withDependencies: {
            $0.createNote.execute = { _, _, _ in throw TestError.someError }
            $0.toastPresenter.present = { value in
                toasts.withValue { $0.append(value) }
            }
        }

        await store.send(.view(.addButtonTapped)) {
            $0.isCreating = true
        }
        // The draft survives the error: losing the user's text along with the request would make
        // a flaky connection cost them the note twice.
        await store.receive(\.notesResult) {
            $0.isCreating = false
        }
        #expect(store.state.draft == "Filed under Q3")
        #expect(store.state.loadError == nil)
        #expect(toasts.value == [.error(TestError.someError.localizedDescription)])
    }

    @Test
    func test_view_deleteButtonTapped_confirmsWithTheSwipedNote() async throws {
        let target = Note.testValue(id: 2, note: "Filed under Q3")
        let confirmed = LockIsolated([Note.Id]())
        let store = TestStore(
            initialState: DocumentNotesReducer.State.testValue(notes: [.testValue(), target])
        ) {
            DocumentNotesReducer()
        } withDependencies: {
            $0.documentNoteDeleteConfirmation.present = { true }
            $0.deleteNote.execute = { _, noteId, _ in
                confirmed.withValue { $0.append(noteId) }
                return [.testValue()]
            }
        }

        await store.send(.view(.deleteButtonTapped(target.id)))
        await store.receive(\.deleteConfirmed) {
            $0.deletingNoteId = target.id
        }
        await store.receive(\.notesResult) {
            $0.deletingNoteId = nil
            $0.notes = [.testValue()]
        }
        #expect(confirmed.value == [target.id])
    }

    @Test
    func test_view_deleteButtonTapped_unknownNote_doesNotConfirm() async throws {
        let store = TestStore(
            initialState: DocumentNotesReducer.State.testValue(notes: [.testValue()])
        ) {
            DocumentNotesReducer()
        } withDependencies: {
            $0.documentNoteDeleteConfirmation.present = {
                Issue.record("A row the latest response already removed must not open a popup.")
                return false
            }
        }

        await store.send(.view(.deleteButtonTapped(99)))
    }

    @Test
    func test_deleteConfirmed_deletes() async throws {
        let remaining = [Note.testValue()]
        let target = Note.testValue(id: 2, note: "Filed under Q3")
        let store = TestStore(
            initialState: DocumentNotesReducer.State.testValue(notes: [.testValue(), target])
        ) {
            DocumentNotesReducer()
        } withDependencies: {
            $0.deleteNote.execute = { _, noteId, _ in
                #expect(noteId == target.id)
                return remaining
            }
        }

        await store.send(.deleteConfirmed(target.id)) {
            $0.deletingNoteId = target.id
        }
        await store.receive(\.notesResult) {
            $0.deletingNoteId = nil
            $0.notes = IdentifiedArray(uniqueElements: remaining)
        }
    }

    @Test
    func test_view_deleteButtonTapped_cancelled_doesNotDelete() async throws {
        let target = Note.testValue()
        let store = TestStore(
            initialState: DocumentNotesReducer.State.testValue(notes: [target])
        ) {
            DocumentNotesReducer()
        } withDependencies: {
            $0.documentNoteDeleteConfirmation.present = { false }
            $0.deleteNote.execute = { _, _, _ in
                Issue.record("Cancelling the popup must leave the note alone.")
                return []
            }
        }

        await store.send(.view(.deleteButtonTapped(target.id)))
    }

    @Test
    func test_delete_failure_leavesTheListIntact() async throws {
        let target = Note.testValue()
        let toasts = LockIsolated<[Toast]>([])
        let store = TestStore(
            initialState: DocumentNotesReducer.State.testValue(notes: [target])
        ) {
            DocumentNotesReducer()
        } withDependencies: {
            $0.deleteNote.execute = { _, _, _ in throw TestError.someError }
            $0.toastPresenter.present = { value in
                toasts.withValue { $0.append(value) }
            }
        }

        await store.send(.deleteConfirmed(target.id)) {
            $0.deletingNoteId = target.id
        }
        await store.receive(\.notesResult) {
            $0.deletingNoteId = nil
        }
        // A failed delete only toasts. The list on screen is still an accurate picture of the
        // server, so it must not fall back to the error state a failed load uses.
        #expect(store.state.notes == [target])
        #expect(store.state.loadError == nil)
        #expect(toasts.value == [.error(TestError.someError.localizedDescription)])
    }
}
