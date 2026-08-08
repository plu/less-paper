import ApiInterface
import Dependencies
import DependenciesMacros
import Foundation
import IdentifiedCollections
import SwiftSharing

extension SaveStoragePathUseCase: @retroactive DependencyKey {
    public static let liveValue = Self(
        execute: execute(id:input:server:)
    )
}

private extension SaveStoragePathUseCase {

    static func execute(
        id: StoragePath.Id?,
        input: SaveStoragePathInput,
        server: Server
    ) async throws -> SaveStoragePathOutput {
        @Shared(.storagePaths(server))
        var cache: IdentifiedArrayOf<StoragePath> = []

        @Dependency(\.storagePathsRepository)
        var storagePathsRepository

        let result: SaveStoragePathOutput

        if let id {
            result = try await storagePathsRepository.updateStoragePath(
                id: id,
                input: input,
                server: server
            )
        } else {
            result = try await storagePathsRepository.createStoragePath(
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
