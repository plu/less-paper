import ApiInterface
import Dependencies
import DependenciesMacros
import Foundation
import IdentifiedCollections
import SwiftSharing

extension SaveFavoriteUseCase: @retroactive DependencyKey {
    public static let liveValue = Self(execute: execute(document:server:))
}

private extension SaveFavoriteUseCase {

    static func execute(document: Document, server: Server) async throws {
        @Dependency(\.date.now) var now
        @Dependency(\.downloadDocument.execute) var downloadDocument
        @Dependency(\.favoritesStore) var store
        @Dependency(\.getDocumentMetadata.execute) var getMetadata
        @Dependency(\.getNotes.execute) var getNotes

        // Everything is fetched before anything is stored, so a failure anywhere leaves no
        // half-written favorite.
        let notes = try await getNotes(document.id, server)
        let metadata = try await getMetadata(document.id, server)
        let data = try await downloadDocument(document.id, server)
        let byteCount = try await store.writePDF(data, document.id, server)

        @Shared(.favorites(server)) var favorites: IdentifiedArrayOf<FavoriteDocument> = []

        $favorites.withLock {
            $0[id: document.id] = FavoriteDocument(
                document: document,
                metadata: metadata,
                notes: notes,
                pdfByteCount: byteCount,
                storedAt: now
            )
        }
    }
}
