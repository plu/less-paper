import ApiInterface
import Dependencies
import DependenciesMacros
import Foundation
import IdentifiedCollections
import SwiftSharing

extension SaveFavoriteUseCase: @retroactive DependencyKey {
    public static let liveValue = Self(execute: execute(document:server:mode:))
}

private extension SaveFavoriteUseCase {

    static func execute(document: Document, server: Server, mode: SaveFavoriteMode) async throws {
        @Dependency(\.date.now) var now
        @Dependency(\.downloadDocument.execute) var downloadDocument
        @Dependency(\.favoritesStore) var store
        @Dependency(\.getDocument.execute) var getDocument
        @Dependency(\.getDocumentMetadata.execute) var getMetadata
        @Dependency(\.getNotes.execute) var getNotes

        // Everything is fetched before anything is stored, so a failure anywhere leaves no
        // half-written favorite.

        // The document handed in came from a list response, which paperless truncates
        // (`truncate_content=true`), so its `content` is a preview. A favorite has to hold the whole
        // thing or the offline viewer shows partial text and says nothing about it.
        let full = try await getDocument(document.id, server)
        let notes = try await getNotes(document.id, server)
        let metadata = try await getMetadata(document.id, server)
        let data = try await downloadDocument(document.id, server)
        let byteCount = try await store.writePDF(data, document.id, server)

        @Shared(.favorites(server)) var favorites: IdentifiedArrayOf<FavoriteDocument> = []

        // Checked and written under one lock: a refresh must not resurrect a favorite the user
        // removed while the fetch above was in flight, and a remove must not be able to land
        // between the check and the write.
        let wrote = $favorites.withLock { favorites -> Bool in
            guard mode == .add || favorites[id: document.id] != nil else {
                return false
            }

            // Keyed and gated on the id that was handed in; only the persisted value is the
            // untruncated copy. `syncedModified` stays the list copy's `modified`, because that is
            // the field the refresh gate compares against.
            favorites[id: document.id] = FavoriteDocument(
                document: full,
                metadata: metadata,
                notes: notes,
                pdfByteCount: byteCount,
                storedAt: now,
                syncedModified: document.modified
            )
            return true
        }

        // Losing that race would otherwise strand the PDF written above with no record pointing
        // at it, and nothing left to delete it.
        if !wrote {
            try await store.deletePDF(document.id, server)
        }
    }
}
