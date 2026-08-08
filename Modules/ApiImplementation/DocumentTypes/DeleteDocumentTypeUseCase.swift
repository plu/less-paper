import ApiInterface
import Dependencies
import DependenciesMacros
import Foundation
import IdentifiedCollections
import SwiftSharing

extension DeleteDocumentTypeUseCase: @retroactive DependencyKey {
    public static let liveValue = Self(
        execute: execute(id:server:)
    )
}

private extension DeleteDocumentTypeUseCase {

    static func execute(
        id: DocumentType.Id,
        server: Server
    ) async throws {
        @Shared(.documentTypes(server))
        var cache: IdentifiedArrayOf<DocumentType> = []

        @Dependency(\.documentTypesRepository)
        var documentTypesRepository

        try await documentTypesRepository.deleteDocumentType(
            id: id,
            server: server
        )

        _ = $cache.withLock { $0.remove(id: id) }
    }
}
