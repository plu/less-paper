import Dependencies
import Foundation
import Tagged

public struct Correspondent: Codable, Equatable, Hashable, Identifiable, Sendable {
    public typealias Id = Tagged<Correspondent, Int>

    public let documentCount: Int

    public let id: Id

    public let isInsensitive: Bool

    public let match: String

    public let matchingAlgorithm: MatchingAlgorithm

    public let name: String

    public let owner: User.Id?

    public let slug: String

    public let userCanChange: Bool

    public init(
        documentCount: Int,
        id: Id,
        isInsensitive: Bool,
        match: String,
        matchingAlgorithm: MatchingAlgorithm = .automatic,
        name: String,
        owner: User.Id?,
        slug: String,
        userCanChange: Bool
    ) {
        self.documentCount = documentCount
        self.id = id
        self.isInsensitive = isInsensitive
        self.match = match
        self.matchingAlgorithm = matchingAlgorithm
        self.name = name
        self.owner = owner
        self.slug = slug
        self.userCanChange = userCanChange
    }
}

public extension Correspondent {

    private enum CodingKeys: String, CodingKey {
        case documentCount, id, isInsensitive, match, matchingAlgorithm, name, owner, slug, userCanChange
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        documentCount = try container.decodeIfPresent(Int.self, forKey: .documentCount) ?? 0
        id = try container.decode(Id.self, forKey: .id)
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
        try container.encode(documentCount, forKey: .documentCount)
        try container.encode(id, forKey: .id)
        try container.encode(isInsensitive, forKey: .isInsensitive)
        try container.encode(match, forKey: .match)
        try container.encode(matchingAlgorithm, forKey: .matchingAlgorithm)
        try container.encode(name, forKey: .name)
        try container.encode(owner, forKey: .owner)
        try container.encode(slug, forKey: .slug)
        try container.encode(userCanChange, forKey: .userCanChange)
    }
}

public extension Correspondent {

    static func testValue(
        documentCount: Int = 0,
        id: Id = 1,
        isInsensitive: Bool = false,
        match: String = "",
        matchingAlgorithm: MatchingAlgorithm = .automatic,
        name: String = "Test Correspondent",
        owner: User.Id? = 3,
        slug: String = "test-correspondent",
        userCanChange: Bool = true
    ) -> Self {
        .init(
            documentCount: documentCount,
            id: id,
            isInsensitive: isInsensitive,
            match: match,
            matchingAlgorithm: matchingAlgorithm,
            name: name,
            owner: owner,
            slug: slug,
            userCanChange: userCanChange
        )
    }
}

public extension Array where Element == Correspondent {

    static var previewValue: Self {
        (1 ... 5).map {
            .testValue(
                documentCount: $0 * 3,
                id: .init($0),
                name: "Correspondent \($0)",
                slug: "correspondent-\($0)"
            )
        }
    }
}

extension Correspondent: Comparable {
    public static func < (lhs: Correspondent, rhs: Correspondent) -> Bool {
        lhs.name < rhs.name
    }
}

extension Correspondent: CustomStringConvertible {
    public var description: String {
        name
    }
}

public extension Correspondent.Id {

    func get(_ server: Server) -> Correspondent? {
        @Dependency(\.apiCache)
        var apiCache

        return apiCache.correspondent(id: self, server: server)
    }
}
