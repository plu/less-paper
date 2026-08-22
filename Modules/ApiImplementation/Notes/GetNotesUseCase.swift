import ApiInterface
import Dependencies
import DependenciesMacros
import Foundation

extension GetNotesUseCase: @retroactive DependencyKey {
    public static let liveValue = Self(
        execute: execute(documentId:server:)
    )
}

private extension GetNotesUseCase {

    static func execute(
        documentId: Document.Id,
        server: Server
    ) async throws -> [Note] {
        @Dependency(\.notesRepository)
        var repository

        return try await repository.getNotes(
            documentId: documentId,
            server: server
        )
    }
}
