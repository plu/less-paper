import Foundation
import Tagged

public struct FavoriteDocument: Codable, Equatable, Hashable, Identifiable, Sendable {

    public var id: Document.Id { document.id }

    public let document: Document

    public let metadata: DocumentMetadata?

    public let notes: [Note]

    public let pdfByteCount: Int

    public let storedAt: Date

    // Set by a refresh whose id__in response did not include this document. Mutable because it is
    // the one field that changes without the document behind it changing.
    public var isUnavailable: Bool

    public init(
        document: Document,
        metadata: DocumentMetadata?,
        notes: [Note],
        pdfByteCount: Int,
        storedAt: Date,
        isUnavailable: Bool = false
    ) {
        self.document = document
        self.metadata = metadata
        self.notes = notes
        self.pdfByteCount = pdfByteCount
        self.storedAt = storedAt
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
        isUnavailable: Bool = false
    ) -> Self {
        .init(
            document: document,
            metadata: metadata,
            notes: notes,
            pdfByteCount: pdfByteCount,
            storedAt: storedAt,
            isUnavailable: isUnavailable
        )
    }
}
