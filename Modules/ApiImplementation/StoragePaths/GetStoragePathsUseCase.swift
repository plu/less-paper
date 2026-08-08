import ApiInterface
import Dependencies
import DependenciesMacros
import Foundation
import IdentifiedCollections
import SwiftSharing

extension GetStoragePathsUseCase: @retroactive DependencyKey {
    public static let liveValue = Self(
        execute: execute(server:)
    )
}

private extension GetStoragePathsUseCase {

    static func execute(
        server: Server
    ) async throws -> [StoragePath] {
        @Shared(.storagePaths(server))
        var cache: IdentifiedArrayOf<StoragePath> = []

        @Dependency(\.storagePathsRepository)
        var repository

        var output = try await repository.getStoragePaths(
            input: .init(),
            server: server
        )
        var result = output.results

        while let url = output.next {
            output = try await repository.getStoragePaths(
                input: .init(url: url),
                server: server
            )
            result.append(contentsOf: output.results)
        }

        $cache.withLock { $0 = IdentifiedArray(uniqueElements: result) }

        return result
    }
}
