import ApiInterface
import Dependencies
import DependenciesMacros
import Foundation
import IdentifiedCollections
import SwiftSharing

extension SaveDocumentTypeUseCase: @retroactive DependencyKey {
    public static let liveValue = Self(
        execute: execute(id:input:server:)
    )
}

private extension SaveDocumentTypeUseCase {

    static func execute(
        id: DocumentType.Id?,
        input: SaveDocumentTypeInput,
        server: Server
    ) async throws -> SaveDocumentTypeOutput {
        @Shared(.documentTypes(server))
        var cache: IdentifiedArrayOf<DocumentType> = []

        @Dependency(\.documentTypesRepository)
        var documentTypesRepository

        let result: SaveDocumentTypeOutput

        if let id {
            result = try await documentTypesRepository.updateDocumentType(
                id: id,
                input: input,
                server: server
            )
        } else {
            result = try await documentTypesRepository.createDocumentType(
                input: input,
                server: server
            )
        }

        $cache.withLock { cache in
            cache.updateOrAppend(result)
            cache.sort {
                $0.name.compare(
                    $1.name,
                    options: [
                        .caseInsensitive,
                        .numeric,
                        .forcedOrdering
                    ]
                ) == .orderedAscending
            }
        }

        return result
    }
}
