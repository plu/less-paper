import ApiInterface
import Dependencies
import DependenciesMacros
import Foundation

extension GetShareLinksUseCase: @retroactive DependencyKey {
    public static let liveValue = Self(
        execute: execute(documentId:server:)
    )
}

private extension GetShareLinksUseCase {

    static func execute(
        documentId: Document.Id,
        server: Server
    ) async throws -> [ShareLink] {
        @Dependency(\.shareLinksRepository)
        var repository

        return try await repository.getShareLinks(
            documentId: documentId,
            server: server
        )
    }
}
