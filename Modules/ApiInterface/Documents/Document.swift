import Foundation
import Tagged

public struct Document: Codable, Equatable, Hashable, Identifiable, Sendable {

    public typealias Id = Tagged<Document, Int>

    public let added: Date

    public let archiveSerialNumber: Int?

    public let archivedFileName: String?

    public let content: String?

    public let correspondent: Correspondent.Id?

    public let created: Date

    public let createdDate: Date

    public let documentType: DocumentType.Id?

    public let id: Id

    public let modified: Date

    public let originalFileName: String?

    public let owner: User.Id?

    public let storagePath: StoragePath.Id?

    public let tags: [Tag.Id]

    public let title: String

    public init(
        added: Date,
        archiveSerialNumber: Int?,
        archivedFileName: String?,
        content: String?,
        correspondent: Correspondent.Id?,
        created: Date,
        createdDate: Date,
        documentType: DocumentType.Id?,
        id: Id,
        modified: Date,
        originalFileName: String?,
        owner: User.Id?,
        storagePath: StoragePath.Id?,
        tags: [Tag.Id],
        title: String
    ) {
        self.added = added
        self.archiveSerialNumber = archiveSerialNumber
        self.archivedFileName = archivedFileName
        self.content = content
        self.correspondent = correspondent
        self.created = created
        self.createdDate = createdDate
        self.documentType = documentType
        self.id = id
        self.modified = modified
        self.originalFileName = originalFileName
        self.owner = owner
        self.storagePath = storagePath
        self.tags = tags
        self.title = title
    }
}

public extension Document {
    var fileName: String {
        archivedFileName ?? originalFileName ?? "document.pdf"
    }
}

public extension Document {

    static func testValue(
        added: Date = .testValue(),
        archiveSerialNumber: Int? = 42,
        archivedFileName: String? = "invoice.pdf",
        content: String? = "Some invoice",
        correspondent: Correspondent.Id? = 1,
        created: Date = .testValue(),
        createdDate: Date = .testValue(),
        documentType: DocumentType.Id? = 1,
        id: Id = 1,
        modified: Date = .testValue(),
        originalFileName: String? = "invoice.pdf",
        owner: User.Id? = 1,
        storagePath: StoragePath.Id? = 1,
        tags: [Tag.Id] = [1],
        title: String = "Invoice"
    ) -> Self {
        .init(
            added: added,
            archiveSerialNumber: archiveSerialNumber,
            archivedFileName: archivedFileName,
            content: content,
            correspondent: correspondent,
            created: created,
            createdDate: createdDate,
            documentType: documentType,
            id: id,
            modified: modified,
            originalFileName: originalFileName,
            owner: owner,
            storagePath: storagePath,
            tags: tags,
            title: title
        )
    }
}
