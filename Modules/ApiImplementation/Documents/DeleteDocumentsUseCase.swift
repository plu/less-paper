import ApiInterface
import Dependencies
import DependenciesMacros
import Foundation
import IdentifiedCollections
import SwiftSharing

extension DeleteDocumentsUseCase: @retroactive DependencyKey {
    public static let liveValue = Self(
        execute: execute(ids:server:)
    )
}

private extension DeleteDocumentsUseCase {

    /**
     * Deletes documents on the server and evicts them from the shared document cache.
     *
     * Deletion goes through `bulk_edit` rather than the per-document endpoint because the
     * endpoint is inherently batched and is already exercised by the repository integration
     * tests.
     *
     * - Parameters:
     *   - ids: The documents to delete.
     *   - server: The server to delete them from.
     */
    static func execute(
        ids: [Document.Id],
        server: Server
    ) async throws {
        @Shared(.documents(server))
        var cache: IdentifiedArrayOf<Document> = []

        @Dependency(\.documentsRepository)
        var documentsRepository

        try await documentsRepository.bulkEditDocuments(
            .init(documents: ids, method: .delete),
            server
        )

        $cache.withLock { cache in
            for id in ids {
                cache.remove(id: id)
            }
        }
    }
}
