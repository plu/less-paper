import ApiInterface
import Dependencies
import DependenciesMacros
import Foundation

extension GetDocumentUseCase: @retroactive DependencyKey {
    public static let liveValue = Self(
        execute: execute(id:server:)
    )
}

private extension GetDocumentUseCase {

    static func execute(
        id: Document.Id,
        server: Server
    ) async throws -> Document {
        @Dependency(\.documentsRepository)
        var repository

        return try await repository.getDocument(
            id: id,
            server: server
        )
    }
}
