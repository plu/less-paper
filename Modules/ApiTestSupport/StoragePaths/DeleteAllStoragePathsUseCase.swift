import ApiInterface
import Dependencies
import DependenciesMacros
import Foundation
import IdentifiedCollections

extension DeleteAllStoragePathsUseCase: @retroactive DependencyKey {
    public static let liveValue = Self(
        execute: execute(server:)
    )
}

private extension DeleteAllStoragePathsUseCase {

    static func execute(
        server: Server
    ) async throws {
        @Dependency(\.getStoragePaths.execute)
        var getStoragePaths

        @Dependency(\.deleteStoragePath.execute)
        var deleteStoragePath

        let storagePaths = try await getStoragePaths(server)

        for storagePath in storagePaths {
            try await deleteStoragePath(storagePath.id, server)
        }
    }
}
