import ApiInterface
import Dependencies
import DependenciesMacros
import Foundation
import IdentifiedCollections
import SwiftSharing

extension GetDocumentTypesUseCase: @retroactive DependencyKey {
    public static let liveValue = Self(
        execute: execute(server:)
    )
}

private extension GetDocumentTypesUseCase {

    static func execute(
        server: Server
    ) async throws -> [DocumentType] {
        @Shared(.documentTypes(server))
        var cache: IdentifiedArrayOf<DocumentType> = []

        @Dependency(\.documentTypesRepository)
        var repository

        var output = try await repository.getDocumentTypes(
            input: .init(),
            server: server
        )
        var result = output.results

        while let url = output.next {
            output = try await repository.getDocumentTypes(
                input: .init(url: url),
                server: server
            )
            result.append(contentsOf: output.results)
        }

        $cache.withLock { $0 = IdentifiedArray(uniqueElements: result) }

        return result
    }
}
