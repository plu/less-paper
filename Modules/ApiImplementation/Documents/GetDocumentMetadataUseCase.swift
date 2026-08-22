import ApiInterface
import Dependencies
import DependenciesMacros
import Foundation

extension GetDocumentMetadataUseCase: @retroactive DependencyKey {
    public static let liveValue = Self(
        execute: execute(id:server:)
    )
}

private extension GetDocumentMetadataUseCase {

    static func execute(
        id: Document.Id,
        server: Server
    ) async throws -> DocumentMetadata {
        @Dependency(\.documentsRepository)
        var repository

        return try await repository.getDocumentMetadata(
            id: id,
            server: server
        )
    }
}
