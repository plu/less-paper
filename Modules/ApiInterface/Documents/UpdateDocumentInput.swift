import Foundation

public struct UpdateDocumentInput: Encodable, Equatable, Sendable {

    @NullEncodable
    public var archiveSerialNumber: Int?

    // A plain optional, not @NullEncodable: nil must omit the key so the server leaves content
    // untouched. Encoding an explicit null here would blank the document.
    public let content: String?

    @NullEncodable
    public var correspondent: Correspondent.Id?

    public let createdDate: Date

    public let customFields: [DocumentCustomField]

    @NullEncodable
    public var documentType: DocumentType.Id?

    @NullEncodable
    public var storagePath: StoragePath.Id?

    public let tags: [Tag.Id]

    public let title: String

    public init(
        archiveSerialNumber: Int?,
        content: String?,
        correspondent: Correspondent.Id?,
        createdDate: Date,
        customFields: [DocumentCustomField],
        documentType: DocumentType.Id?,
        storagePath: StoragePath.Id?,
        tags: [Tag.Id],
        title: String
    ) {
        self.archiveSerialNumber = archiveSerialNumber
        self.content = content
        self.correspondent = correspondent
        self.createdDate = createdDate
        self.customFields = customFields
        self.documentType = documentType
        self.storagePath = storagePath
        self.tags = tags
        self.title = title
    }
}

public extension UpdateDocumentInput {

    static func testValue(
        archiveSerialNumber: Int? = nil,
        content: String? = nil,
        correspondent: Correspondent.Id? = nil,
        createdDate: Date = .distantPast,
        customFields: [DocumentCustomField] = [],
        documentType: DocumentType.Id? = nil,
        storagePath: StoragePath.Id? = nil,
        tags: [Tag.Id] = [],
        title: String = "Test Document"
    ) -> Self {
        .init(
            archiveSerialNumber: archiveSerialNumber,
            content: content,
            correspondent: correspondent,
            createdDate: createdDate,
            customFields: customFields,
            documentType: documentType,
            storagePath: storagePath,
            tags: tags,
            title: title
        )
    }
}
