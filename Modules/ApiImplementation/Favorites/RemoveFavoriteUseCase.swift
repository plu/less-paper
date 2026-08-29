import ApiInterface
import Dependencies
import DependenciesMacros
import Foundation
import IdentifiedCollections
import SwiftSharing

extension RemoveFavoriteUseCase: @retroactive DependencyKey {
    public static let liveValue = Self(execute: execute(id:server:))
}

private extension RemoveFavoriteUseCase {

    static func execute(id: Document.Id, server: Server) async throws {
        @Dependency(\.favoritesStore) var store

        try await store.deletePDF(id, server)

        @Shared(.favorites(server)) var favorites: IdentifiedArrayOf<FavoriteDocument> = []

        _ = $favorites.withLock { $0.remove(id: id) }
    }
}
