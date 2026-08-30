import Foundation
import Tagged

public struct FavoriteDocument: Codable, Equatable, Hashable, Identifiable, Sendable {

    public var id: Document.Id { document.id }

    public let document: Document

    public let metadata: DocumentMetadata?

    public let notes: [Note]

    public let pdfByteCount: Int

    public let storedAt: Date

    // The `document.modified` the notes, metadata and PDF were last successfully fetched at, which
    // is not the same as `document.modified`: a refresh stores the server's document even when the
    // download that follows fails. Gating the next refresh on the document's own `modified` would
    // then find them equal and never retry, leaving the favorite stale for good.
    public let syncedModified: Date

    // Set by a refresh whose id__in response did not include this document. Mutable because it is
    // the one field that changes without the document behind it changing.
    public var isUnavailable: Bool

    public init(
        document: Document,
        metadata: DocumentMetadata?,
        notes: [Note],
        pdfByteCount: Int,
        storedAt: Date,
        syncedModified: Date,
        isUnavailable: Bool = false
    ) {
        self.document = document
        self.metadata = metadata
        self.notes = notes
        self.pdfByteCount = pdfByteCount
        self.storedAt = storedAt
        self.syncedModified = syncedModified
        self.isUnavailable = isUnavailable
    }
}

public extension FavoriteDocument {

    static func testValue(
        document: Document = .testValue(),
        metadata: DocumentMetadata? = .testValue(),
        notes: [Note] = [],
        pdfByteCount: Int = 1024,
        storedAt: Date = Date(timeIntervalSince1970: 1_756_290_271),
        syncedModified: Date? = nil,
        isUnavailable: Bool = false
    ) -> Self {
        .init(
            document: document,
            metadata: metadata,
            notes: notes,
            pdfByteCount: pdfByteCount,
            storedAt: storedAt,
            syncedModified: syncedModified ?? document.modified,
            isUnavailable: isUnavailable
        )
    }
}
