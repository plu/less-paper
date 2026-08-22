import ApiInterface
import Dependencies
import DependenciesMacros
import Foundation

extension DeleteNoteUseCase: @retroactive DependencyKey {
    public static let liveValue = Self(
        execute: execute(documentId:noteId:server:)
    )
}

private extension DeleteNoteUseCase {

    static func execute(
        documentId: Document.Id,
        noteId: Note.Id,
        server: Server
    ) async throws -> [Note] {
        @Dependency(\.notesRepository)
        var repository

        return try await repository.deleteNote(
            documentId: documentId,
            noteId: noteId,
            server: server
        )
    }
}
