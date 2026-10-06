@testable import ApiImplementation

import ApiInterface
import Dependencies
import Foundation
import Testing
import TestSupport

@Suite(
    .testDependencies()
)
struct NoteUseCaseTests {

    @Test
    func getNotes_forwardsToRepository() async throws {
        let documentIdReceived = LockIsolated<Document.Id?>(nil)
        try await withDependencies {
            $0.notesRepository.getNotes = { documentId, _ in
                documentIdReceived.setValue(documentId)
                return [.testValue()]
            }
        } operation: {
            let notes = try await GetNotesUseCase.liveValue.execute(
                7,
                .testValue()
            )

            #expect(documentIdReceived.value == 7)
            #expect(notes == [.testValue()])
        }
    }

    @Test
    func createNote_forwardsToRepository() async throws {
        let received = LockIsolated<(Document.Id, CreateNoteInput)?>(nil)
        try await withDependencies {
            $0.notesRepository.createNote = { documentId, input, _ in
                received.setValue((documentId, input))
                return [.testValue()]
            }
        } operation: {
            let notes = try await CreateNoteUseCase.liveValue.execute(
                7,
                .init(note: "hello"),
                .testValue()
            )

            #expect(received.value?.0 == 7)
            #expect(received.value?.1.note == "hello")
            #expect(notes == [.testValue()])
        }
    }

    @Test
    func deleteNote_forwardsToRepository() async throws {
        let received = LockIsolated<(Document.Id, Note.Id)?>(nil)
        try await withDependencies {
            $0.notesRepository.deleteNote = { documentId, noteId, _ in
                received.setValue((documentId, noteId))
                return []
            }
        } operation: {
            let notes = try await DeleteNoteUseCase.liveValue.execute(
                documentId: 7,
                noteId: 3,
                server: .testValue()
            )

            #expect(received.value?.0 == 7)
            #expect(received.value?.1 == 3)
            #expect(notes == [])
        }
    }
}
