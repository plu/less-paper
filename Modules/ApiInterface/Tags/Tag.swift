import Dependencies
import Foundation
import Tagged

public struct Tag: Codable, Equatable, Hashable, Identifiable, Sendable {
    public typealias Id = Tagged<Tag, Int>

    public let color: String

    public let documentCount: Int

    public let id: Id

    public let isInboxTag: Bool

    public let isInsensitive: Bool

    public let match: String

    public let matchingAlgorithm: MatchingAlgorithm

    public let name: String

    public let owner: User.Id?

    public let slug: String

    public let textColor: String

    public let userCanChange: Bool

    public init(
        color: String,
        documentCount: Int,
        id: Id,
        isInboxTag: Bool,
        isInsensitive: Bool,
        match: String,
        matchingAlgorithm: MatchingAlgorithm = .automatic,
        name: String,
        owner: User.Id?,
        slug: String,
        textColor: String,
        userCanChange: Bool
    ) {
        self.color = color
        self.documentCount = documentCount
        self.id = id
        self.isInboxTag = isInboxTag
        self.isInsensitive = isInsensitive
        self.match = match
        self.matchingAlgorithm = matchingAlgorithm
        self.name = name
        self.owner = owner
        self.slug = slug
        self.textColor = textColor
        self.userCanChange = userCanChange
    }
}

public extension Tag {

    private enum CodingKeys: String, CodingKey {
        case color, colour, documentCount, id, isInboxTag, isInsensitive, match, matchingAlgorithm, name, owner, slug,
             textColor,
             userCanChange
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if container.contains(.colour) {
            let colorId = try container.decode(Int.self, forKey: .colour)
            color = tagBackgroundColors[colorId] ?? "#a6cee3"
            textColor = tagTextColors[colorId] ?? "#000000"
        } else {
            color = try container.decode(String.self, forKey: .color)
            textColor = try container.decode(String.self, forKey: .textColor)
        }
        documentCount = try container.decodeIfPresent(Int.self, forKey: .documentCount) ?? 0
        id = try container.decode(Id.self, forKey: .id)
        isInboxTag = try container.decode(Bool.self, forKey: .isInboxTag)
        isInsensitive = try container.decode(Bool.self, forKey: .isInsensitive)
        match = try container.decode(String.self, forKey: .match)
        matchingAlgorithm = try container.decode(MatchingAlgorithm.self, forKey: .matchingAlgorithm)
        name = try container.decode(String.self, forKey: .name)
        owner = try container.decodeIfPresent(User.Id.self, forKey: .owner)
        slug = try container.decode(String.self, forKey: .slug)
        userCanChange = try container.decode(Bool.self, forKey: .userCanChange)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(color, forKey: .color)
        try container.encode(textColor, forKey: .textColor)
        try container.encode(documentCount, forKey: .documentCount)
        try container.encode(id, forKey: .id)
        try container.encode(isInboxTag, forKey: .isInboxTag)
        try container.encode(isInsensitive, forKey: .isInsensitive)
        try container.encode(match, forKey: .match)
        try container.encode(matchingAlgorithm, forKey: .matchingAlgorithm)
        try container.encode(name, forKey: .name)
        try container.encode(owner, forKey: .owner)
        try container.encode(slug, forKey: .slug)
        try container.encode(userCanChange, forKey: .userCanChange)
    }
}

let tagBackgroundColors = [
    1: "#a6cee3",
    2: "#1f78b4",
    3: "#b2df8a",
    4: "#33a02c",
    5: "#fb9a99",
    6: "#e31a1c",
    7: "#fdbf6f",
    8: "#ff7f00",
    9: "#cab2d6",
    10: "#6a3d9a",
    11: "#b15928",
    12: "#000000",
    13: "#cccccc",
]

let tagTextColors = [
    1: "#000000",
    2: "#ffffff",
    3: "#000000",
    4: "#ffffff",
    5: "#000000",
    6: "#ffffff",
    7: "#000000",
    8: "#000000",
    9: "#000000",
    10: "#ffffff",
    11: "#ffffff",
    12: "#ffffff",
    13: "#000000",
]

public extension Tag {

    static func testValue(
        color: String = "#F7CE46",
        documentCount: Int = 0,
        id: Id = 1,
        isInboxTag: Bool = true,
        isInsensitive: Bool = false,
        match: String = "",
        matchingAlgorithm: MatchingAlgorithm = .automatic,
        name: String = "Inbox",
        owner: User.Id? = 3,
        slug: String = "inbox",
        textColor: String = "#000000",
        userCanChange: Bool = true
    ) -> Self {
        .init(
            color: color,
            documentCount: documentCount,
            id: id,
            isInboxTag: isInboxTag,
            isInsensitive: isInsensitive,
            match: match,
            matchingAlgorithm: matchingAlgorithm,
            name: name,
            owner: owner,
            slug: slug,
            textColor: textColor,
            userCanChange: userCanChange
        )
    }
}

public extension Array where Element == Tag {

    static var previewValue: Self {
        (1 ... 13).map {
            .testValue(
                color: tagBackgroundColors[$0]!,
                documentCount: $0 * 2,
                id: .init($0),
                isInboxTag: $0 == 1,
                name: "Tag \($0)",
                textColor: tagTextColors[$0]!
            )
        }
    }
}

extension Tag: Comparable {
    public static func < (lhs: Tag, rhs: Tag) -> Bool {
        lhs.name < rhs.name
    }
}

extension Tag: CustomStringConvertible {
    public var description: String {
        name
    }
}

public extension Tag.Id {

    func get(_ server: Server) -> Tag? {
        @Dependency(\.apiCache)
        var apiCache

        return apiCache.tag(id: self, server: server)
    }
}
