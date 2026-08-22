import ApiInterface
import ComposableArchitecture
import Foundation

extension Effect where Action == DocumentNotesReducer.Action {

    static func runConfirmDelete(noteId: Note.Id) -> Self {
        @Dependency(\.documentNoteDeleteConfirmation.present)
        var presentConfirmation

        return .run { send in
            guard await presentConfirmation() else {
                return
            }
            await send(.deleteConfirmed(noteId))
        }
        .cancellable(id: CancelID.confirmDelete)
    }

    static func runCreateNote(
        documentId: Document.Id,
        input: CreateNoteInput,
        server: Server
    ) -> Self {
        .run { send in
            @Dependency(\.createNote.execute)
            var createNote
            try await send(.notesResult(.create, .success(createNote(documentId, input, server))))
        } catch: { error, send in
            await send(.notesResult(.create, .failure(error)))
        }
    }

    static func runDeleteNote(
        documentId: Document.Id,
        noteId: Note.Id,
        server: Server
    ) -> Self {
        .run { send in
            @Dependency(\.deleteNote.execute)
            var deleteNote
            try await send(.notesResult(.delete, .success(deleteNote(documentId, noteId, server))))
        } catch: { error, send in
            await send(.notesResult(.delete, .failure(error)))
        }
    }

    static func runGetNotes(
        documentId: Document.Id,
        server: Server
    ) -> Self {
        .run { send in
            @Dependency(\.getNotes.execute)
            var getNotes
            try await send(.notesResult(.load, .success(getNotes(documentId, server))))
        } catch: { error, send in
            await send(.notesResult(.load, .failure(error)))
        }
    }
}

private enum CancelID {
    case confirmDelete
}
