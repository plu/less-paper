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

        await refreshStatistics(server: server)
    }
}
