import ApiInterface
import Dependencies
import DependenciesMacros
import Foundation
import IdentifiedCollections
import SwiftSharing

extension GlobalSearchUseCase: @retroactive DependencyKey {
    public static let liveValue = Self(
        execute: execute(query:server:)
    )
}

private extension GlobalSearchUseCase {

    static func execute(
        query: String,
        server: Server
    ) async throws -> GlobalSearchOutput {
        @Dependency(\.globalSearchRepository)
        var repository

        let output = try await repository.search(
            input: .init(query: query),
            server: server
        )

        @Shared(.correspondents(server))
        var correspondents: IdentifiedArrayOf<Correspondent>

        @Shared(.customFields(server))
        var customFields: IdentifiedArrayOf<CustomField>

        @Shared(.documentTypes(server))
        var documentTypes: IdentifiedArrayOf<DocumentType>

        @Shared(.storagePaths(server))
        var storagePaths: IdentifiedArrayOf<StoragePath>

        @Shared(.tags(server))
        var tags: IdentifiedArrayOf<Tag>

        return .init(
            correspondents: resolve(output.correspondents, in: correspondents),
            customFields: resolve(output.customFields, in: customFields),
            documents: output.documents,
            documentTypes: resolve(output.documentTypes, in: documentTypes),
            savedViews: output.savedViews,
            storagePaths: resolve(output.storagePaths, in: storagePaths),
            tags: resolve(output.tags, in: tags)
        )
    }

    // /api/search/ omits document_count, so an entity taken straight from it would carry 0 into the
    // filter sheet. The cached copy is the complete one; the decoded copy is the fallback for
    // anything created since the cache was last refreshed.
    static func resolve<Value: Identifiable>(
        _ values: [Value],
        in cache: IdentifiedArrayOf<Value>
    ) -> [Value] {
        values.map { cache[id: $0.id] ?? $0 }
    }
}
