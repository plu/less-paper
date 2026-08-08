import Foundation

public struct GetStatisticsOutput: Equatable, Hashable, Sendable {

    public let characterCount: Int

    public let correspondentCount: Int

    public let currentAsn: Int

    public let documentFileTypeCounts: [DocumentFileTypeCount]

    public let documentTypeCount: Int

    public let documentsInbox: Int

    public let documentsTotal: Int

    public let inboxTag: Int?

    public let inboxTags: [Int]

    public let storagePathCount: Int

    public let tagCount: Int

    public init(
        characterCount: Int,
        correspondentCount: Int,
        currentAsn: Int,
        documentFileTypeCounts: [DocumentFileTypeCount],
        documentTypeCount: Int,
        documentsInbox: Int,
        documentsTotal: Int,
        inboxTag: Int?,
        inboxTags: [Int],
        storagePathCount: Int,
        tagCount: Int
    ) {
        self.characterCount = characterCount
        self.correspondentCount = correspondentCount
        self.currentAsn = currentAsn
        self.documentFileTypeCounts = documentFileTypeCounts
        self.documentTypeCount = documentTypeCount
        self.documentsInbox = documentsInbox
        self.documentsTotal = documentsTotal
        self.inboxTag = inboxTag
        self.inboxTags = inboxTags
        self.storagePathCount = storagePathCount
        self.tagCount = tagCount
    }

    public struct DocumentFileTypeCount: Codable, Equatable, Hashable, Sendable {

        public let mimeType: String

        public let mimeTypeCount: Int

        public init(mimeType: String, mimeTypeCount: Int) {
            self.mimeType = mimeType
            self.mimeTypeCount = mimeTypeCount
        }
    }
}

extension GetStatisticsOutput: Codable {
    enum CodingKeys: CodingKey {
        case characterCount
        case correspondentCount
        case currentAsn
        case documentFileTypeCounts
        case documentTypeCount
        case documentsInbox
        case documentsTotal
        case inboxTag
        case inboxTags
        case storagePathCount
        case tagCount
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        characterCount = try container.decodeIfPresent(Int.self, forKey: .characterCount) ?? 0
        correspondentCount = try container.decodeIfPresent(Int.self, forKey: .correspondentCount) ?? 0
        currentAsn = try container.decodeIfPresent(Int.self, forKey: .currentAsn) ?? 0
        documentTypeCount = try container.decodeIfPresent(Int.self, forKey: .documentTypeCount) ?? 0
        documentsInbox = try container.decodeIfPresent(Int.self, forKey: .documentsInbox) ?? 0
        documentsTotal = try container.decodeIfPresent(Int.self, forKey: .documentsTotal) ?? 0
        storagePathCount = try container.decodeIfPresent(Int.self, forKey: .storagePathCount) ?? 0
        tagCount = try container.decodeIfPresent(Int.self, forKey: .tagCount) ?? 0

        documentFileTypeCounts = try container.decodeIfPresent([DocumentFileTypeCount].self, forKey: .documentFileTypeCounts) ?? []
        inboxTags = try container.decodeIfPresent([Int].self, forKey: .inboxTags) ?? []

        inboxTag = try container.decodeIfPresent(Int.self, forKey: .inboxTag)
    }
}

public extension GetStatisticsOutput {

    static func testValue(
        characterCount: Int = 11455,
        correspondentCount: Int = 0,
        currentAsn: Int = 2,
        documentFileTypeCounts: [DocumentFileTypeCount] = [
            .init(mimeType: "application/pdf", mimeTypeCount: 15)
        ],
        documentTypeCount: Int = 0,
        documentsInbox: Int = 1,
        documentsTotal: Int = 15,
        inboxTag: Int? = 104,
        inboxTags: [Int] = [104, 105, 106],
        storagePathCount: Int = 0,
        tagCount: Int = 4
    ) -> Self {
        .init(
            characterCount: characterCount,
            correspondentCount: correspondentCount,
            currentAsn: currentAsn,
            documentFileTypeCounts: documentFileTypeCounts,
            documentTypeCount: documentTypeCount,
            documentsInbox: documentsInbox,
            documentsTotal: documentsTotal,
            inboxTag: inboxTag,
            inboxTags: inboxTags,
            storagePathCount: storagePathCount,
            tagCount: tagCount
        )
    }
}
