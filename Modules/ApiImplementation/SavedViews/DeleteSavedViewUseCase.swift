import ApiInterface
import Dependencies
import DependenciesMacros
import Foundation
import IdentifiedCollections
import SwiftSharing

extension DeleteSavedViewUseCase: @retroactive DependencyKey {
    public static let liveValue = Self(
        execute: execute(id:server:)
    )
}

private extension DeleteSavedViewUseCase {

    static func execute(
        id: SavedView.Id,
        server: Server
    ) async throws {
        @Shared(.savedViews(server))
        var cache: IdentifiedArrayOf<SavedView> = []

        @Dependency(\.savedViewsRepository)
        var savedViewsRepository

        try await savedViewsRepository.deleteSavedView(
            id: id,
            server: server
        )

        _ = $cache.withLock { $0.remove(id: id) }
    }
}
