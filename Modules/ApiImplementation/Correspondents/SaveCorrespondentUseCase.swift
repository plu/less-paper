import ApiInterface
import Dependencies
import DependenciesMacros
import Foundation
import IdentifiedCollections
import SwiftSharing

extension SaveCorrespondentUseCase: @retroactive DependencyKey {
    public static let liveValue = Self(
        execute: execute(id:input:server:)
    )
}

private extension SaveCorrespondentUseCase {

    static func execute(
        id: Correspondent.Id?,
        input: SaveCorrespondentInput,
        server: Server
    ) async throws -> SaveCorrespondentOutput {
        @Shared(.correspondents(server))
        var cache: IdentifiedArrayOf<Correspondent> = []

        @Dependency(\.correspondentsRepository)
        var correspondentsRepository

        let result: SaveCorrespondentOutput

        if let id {
            result = try await correspondentsRepository.updateCorrespondent(
                id: id,
                input: input,
                server: server
            )
        } else {
            result = try await correspondentsRepository.createCorrespondent(
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
