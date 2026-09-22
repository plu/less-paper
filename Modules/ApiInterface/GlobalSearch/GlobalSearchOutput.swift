import Foundation

public struct GlobalSearchOutput: Equatable, Sendable {

    public let correspondents: [Correspondent]

    public let customFields: [CustomField]

    public let documents: [Document]

    public let documentTypes: [DocumentType]

    public let savedViews: [SavedView]

    public let storagePaths: [StoragePath]

    public let tags: [Tag]

    public init(
        correspondents: [Correspondent],
        customFields: [CustomField],
        documents: [Document],
        documentTypes: [DocumentType],
        savedViews: [SavedView],
        storagePaths: [StoragePath],
        tags: [Tag]
    ) {
        self.correspondents = correspondents
        self.customFields = customFields
        self.documents = documents
        self.documentTypes = documentTypes
        self.savedViews = savedViews
        self.storagePaths = storagePaths
        self.tags = tags
    }

    public var isEmpty: Bool {
        correspondents.isEmpty
            && customFields.isEmpty
            && documents.isEmpty
            && documentTypes.isEmpty
            && savedViews.isEmpty
            && storagePaths.isEmpty
            && tags.isEmpty
    }
}

extension GlobalSearchOutput: Decodable {

    private enum CodingKeys: String, CodingKey {
        case correspondents, customFields, documents, documentTypes, savedViews, storagePaths, tags
    }

    // Every array is optional on read. `custom_fields` postdates the endpoint, and a key this app
    // has not met must not fail the whole response — the alternative is search breaking entirely
    // against a server one version older. `total`, `users`, `groups`, `mail_accounts`,
    // `mail_rules` and `workflows` are deliberately absent: nothing here can act on them.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        correspondents = try container.decodeIfPresent([Correspondent].self, forKey: .correspondents) ?? []
        customFields = try container.decodeIfPresent([CustomField].self, forKey: .customFields) ?? []
        documents = try container.decodeIfPresent([Document].self, forKey: .documents) ?? []
        documentTypes = try container.decodeIfPresent([DocumentType].self, forKey: .documentTypes) ?? []
        savedViews = try container.decodeIfPresent([SavedView].self, forKey: .savedViews) ?? []
        storagePaths = try container.decodeIfPresent([StoragePath].self, forKey: .storagePaths) ?? []
        tags = try container.decodeIfPresent([Tag].self, forKey: .tags) ?? []
    }
}

public extension GlobalSearchOutput {

    static func testValue(
        correspondents: [Correspondent] = [],
        customFields: [CustomField] = [],
        documents: [Document] = [],
        documentTypes: [DocumentType] = [],
        savedViews: [SavedView] = [],
        storagePaths: [StoragePath] = [],
        tags: [Tag] = []
    ) -> Self {
        .init(
            correspondents: correspondents,
            customFields: customFields,
            documents: documents,
            documentTypes: documentTypes,
            savedViews: savedViews,
            storagePaths: storagePaths,
            tags: tags
        )
    }
}
