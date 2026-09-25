import ApiInterface
import Dependencies
import DependenciesMacros
import Foundation
import IdentifiedCollections
import SwiftSharing

extension SaveOfflineDocumentUseCase: @retroactive DependencyKey {
    public static let liveValue = Self(execute: execute(document:server:mode:))
}

private extension SaveOfflineDocumentUseCase {

    static func execute(document: Document, server: Server, mode: SaveOfflineDocumentMode) async throws {
        @Dependency(\.date.now) var now
        @Dependency(\.downloadDocument.execute) var downloadDocument
        @Dependency(\.offlineStore) var store
        @Dependency(\.getDocument.execute) var getDocument
        @Dependency(\.getDocumentMetadata.execute) var getMetadata
        @Dependency(\.getNotes.execute) var getNotes

        // Everything is fetched before anything is stored, so a failure anywhere leaves no
        // half-written offline document.

        // The document handed in came from a list response, which paperless truncates
        // (`truncate_content=true`), so its `content` is a preview. An offline document has to hold
        // the whole thing or the offline viewer shows partial text and says nothing about it.
        let full = try await getDocument(document.id, server)
        let notes = try await getNotes(document.id, server)
        let metadata = try await getMetadata(document.id, server)
        let data = try await downloadDocument(document.id, server)
        let byteCount = try await store.writePDF(data, document.id, server)

        @Shared(.offlineDocuments(server)) var offlineDocuments: IdentifiedArrayOf<OfflineDocument> = []

        // Checked and written under one lock: a refresh must not resurrect an offline document the
        // user removed while the fetch above was in flight, and a remove must not be able to land
        // between the check and the write.
        let wrote = $offlineDocuments.withLock { offlineDocuments -> Bool in
            guard mode == .add || offlineDocuments[id: document.id] != nil else {
                return false
            }

            // Keyed and gated on the id that was handed in; only the persisted value is the
            // untruncated copy. `syncedModified` stays the list copy's `modified`, because that is
            // the field the refresh gate compares against.
            offlineDocuments[id: document.id] = OfflineDocument(
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
