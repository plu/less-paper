import Foundation

public struct CreateDocumentInput: Codable, Equatable, Sendable {

    public var archiveSerialNumber: Int?

    public var correspondent: Correspondent.Id?

    public var createdDate: Date

    public var documentType: DocumentType.Id?

    public var storagePath: StoragePath.Id?

    public var tags: [Tag.Id]

    public var title: String

    public var url: URL

    public init(
        archiveSerialNumber: Int?,
        correspondent: Correspondent.Id?,
        createdDate: Date,
        documentType: DocumentType.Id?,
        storagePath: StoragePath.Id?,
        tags: [Tag.Id],
        title: String,
        url: URL
    ) {
        self.archiveSerialNumber = archiveSerialNumber
        self.correspondent = correspondent
        self.createdDate = createdDate
        self.documentType = documentType
        self.storagePath = storagePath
        self.tags = tags
        self.title = title
        self.url = url
    }
}

public extension CreateDocumentInput {

    static func testValue(
        archiveSerialNumber: Int? = nil,
        correspondent: Correspondent.Id? = nil,
        createdDate: Date = .distantPast,
        documentType: DocumentType.Id? = nil,
        storagePath: StoragePath.Id? = nil,
        tags: [Tag.Id] = [],
        title: String = "Test Document",
        url: URL = URL(fileURLWithPath: "/tmp/document.pdf")
    ) -> Self {
        .init(
            archiveSerialNumber: archiveSerialNumber,
            correspondent: correspondent,
            createdDate: createdDate,
            documentType: documentType,
            storagePath: storagePath,
            tags: tags,
            title: title,
            url: url
        )
    }
}
