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

        @Shared(.favorites(server)) var favorites: IdentifiedArrayOf<FavoriteDocument> = []

        // The record goes first. Deleting the file first leaves a window in which a refresh's
        // save, already past its download, still sees the record, writes it, and strands the PDF
        // it wrote when this remove drops the record a moment later. Dropping the record first
        // means that save fails its own membership check and cleans up after itself instead.
        _ = $favorites.withLock { $0.remove(id: id) }

        try await store.deletePDF(id, server)
    }
}
