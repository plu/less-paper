import ApiInterface
import Dependencies
import DependenciesMacros
import Foundation
import IdentifiedCollections
import SwiftSharing

extension SaveTagUseCase: @retroactive DependencyKey {
    public static let liveValue = Self(
        execute: execute(id:input:server:)
    )
}

private extension SaveTagUseCase {

    static func execute(
        id: Tag.Id?,
        input: SaveTagInput,
        server: Server
    ) async throws -> SaveTagOutput {
        @Shared(.tags(server))
        var cache: IdentifiedArrayOf<Tag> = []

        @Dependency(\.tagsRepository)
        var tagsRepository

        let result: SaveTagOutput

        if let id {
            result = try await tagsRepository.updateTag(
                id: id,
                input: input,
                server: server
            )
        } else {
            result = try await tagsRepository.createTag(
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
