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

    private enum CodingKeys: String, CodingKey {
        case added, archiveSerialNumber, archivedFileName, content, correspondent, created
        case createdDate, documentType, id, modified, originalFileName, owner, storagePath
        case tags, title
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        added = try container.decode(Date.self, forKey: .added)
        archiveSerialNumber = try container.decodeIfPresent(Int.self, forKey: .archiveSerialNumber)
        archivedFileName = try container.decodeIfPresent(String.self, forKey: .archivedFileName)
        content = try container.decodeIfPresent(String.self, forKey: .content)
        correspondent = try container.decodeIfPresent(Correspondent.Id.self, forKey: .correspondent)
        // API 8 sends `created` as a datetime at the server's local midnight; API 9 made it a plain
        // date. Rendered in the device's time zone that instant can land on the day before, so the
        // calendar date is read from `created_date`, which is date-only on every version. That
        // field is deprecated upstream, and `created` is the right fallback once it is dropped.
        created = try container.decodeIfPresent(Date.self, forKey: .createdDate)
            ?? container.decode(Date.self, forKey: .created)
        documentType = try container.decodeIfPresent(DocumentType.Id.self, forKey: .documentType)
        id = try container.decode(Id.self, forKey: .id)
        modified = try container.decode(Date.self, forKey: .modified)
        originalFileName = try container.decodeIfPresent(String.self, forKey: .originalFileName)
        owner = try container.decodeIfPresent(User.Id.self, forKey: .owner)
        storagePath = try container.decodeIfPresent(StoragePath.Id.self, forKey: .storagePath)
        tags = try container.decode([Tag.Id].self, forKey: .tags)
        title = try container.decode(String.self, forKey: .title)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(added, forKey: .added)
        try container.encode(archiveSerialNumber, forKey: .archiveSerialNumber)
        try container.encode(archivedFileName, forKey: .archivedFileName)
        try container.encode(content, forKey: .content)
        try container.encode(correspondent, forKey: .correspondent)
        try container.encode(created, forKey: .created)
        try container.encode(documentType, forKey: .documentType)
        try container.encode(id, forKey: .id)
        try container.encode(modified, forKey: .modified)
        try container.encode(originalFileName, forKey: .originalFileName)
        try container.encode(owner, forKey: .owner)
        try container.encode(storagePath, forKey: .storagePath)
        try container.encode(tags, forKey: .tags)
        try container.encode(title, forKey: .title)
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
