import ApiInterface
import Dependencies
import DependenciesMacros
import Foundation

extension CreateNoteUseCase: @retroactive DependencyKey {
    public static let liveValue = Self(
        execute: execute(documentId:input:server:)
    )
}

private extension CreateNoteUseCase {

    static func execute(
        documentId: Document.Id,
        input: CreateNoteInput,
        server: Server
    ) async throws -> [Note] {
        @Dependency(\.notesRepository)
        var repository

        return try await repository.createNote(
            documentId: documentId,
            input: input,
            server: server
        )
    }
}
