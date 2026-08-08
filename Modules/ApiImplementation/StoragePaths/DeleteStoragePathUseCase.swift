import ApiInterface
import Dependencies
import DependenciesMacros
import Foundation
import IdentifiedCollections
import SwiftSharing

extension DeleteStoragePathUseCase: @retroactive DependencyKey {
    public static let liveValue = Self(
        execute: execute(id:server:)
    )
}

private extension DeleteStoragePathUseCase {

    static func execute(
        id: StoragePath.Id,
        server: Server
    ) async throws {
        @Shared(.storagePaths(server))
        var cache: IdentifiedArrayOf<StoragePath> = []

        @Dependency(\.storagePathsRepository)
        var storagePathsRepository

        try await storagePathsRepository.deleteStoragePath(
            id: id,
            server: server
        )

        _ = $cache.withLock { $0.remove(id: id) }
    }
}
