import ApiInterface
import Dependencies
import DependenciesMacros
import Foundation
import IdentifiedCollections
import SwiftSharing

extension SaveSavedViewUseCase: @retroactive DependencyKey {
    public static let liveValue = Self(
        execute: execute(id:input:server:)
    )
}

private extension SaveSavedViewUseCase {

    static func execute(
        id: SavedView.Id?,
        input: SaveSavedViewInput,
        server: Server
    ) async throws -> SaveSavedViewOutput {
        @Shared(.savedViews(server))
        var cache: IdentifiedArrayOf<SavedView> = []

        @Dependency(\.savedViewsRepository)
        var savedViewsRepository

        let result: SaveSavedViewOutput

        if let id {
            result = try await savedViewsRepository.updateSavedView(
                id: id,
                input: input,
                server: server
            )
        } else {
            result = try await savedViewsRepository.createSavedView(
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
