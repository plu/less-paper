import Dependencies
import Foundation
import Tagged

public struct StoragePath: Codable, Equatable, Hashable, Identifiable, Sendable {
    public typealias Id = Tagged<StoragePath, Int>

    public let documentCount: Int

    public let id: Id

    public let isInsensitive: Bool

    public let match: String

    public let matchingAlgorithm: MatchingAlgorithm

    public let name: String

    public let owner: User.Id?

    public let path: String

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
        path: String,
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
        self.path = path
        self.slug = slug
        self.userCanChange = userCanChange
    }
}

public extension StoragePath {

    private enum CodingKeys: String, CodingKey {
        case documentCount, id, isInsensitive, match, matchingAlgorithm, name, owner, path, slug, userCanChange
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
        path = try container.decode(String.self, forKey: .path)
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
        try container.encode(path, forKey: .path)
        try container.encode(slug, forKey: .slug)
        try container.encode(userCanChange, forKey: .userCanChange)
    }
}

public extension StoragePath {

    static func testValue(
        documentCount: Int = 0,
        id: Id = 1,
        isInsensitive: Bool = false,
        match: String = "",
        matchingAlgorithm: MatchingAlgorithm = .automatic,
        name: String = "Test StoragePath",
        owner: User.Id? = 3,
        path: String = "/home/paperless/test-storagepath",
        slug: String = "test-storagepath",
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
            path: path,
            slug: slug,
            userCanChange: userCanChange
        )
    }
}

public extension Array where Element == StoragePath {

    static var previewValue: Self {
        (1 ... 5).map {
            .testValue(
                documentCount: $0 * 3,
                id: .init($0),
                name: "StoragePath \($0)",
                slug: "storagePath-\($0)"
            )
        }
    }
}

extension StoragePath: Comparable {
    public static func < (lhs: StoragePath, rhs: StoragePath) -> Bool {
        lhs.name < rhs.name
    }
}

extension StoragePath: CustomStringConvertible {
    public var description: String {
        name
    }
}

public extension StoragePath.Id {

    func get(_ server: Server) -> StoragePath? {
        @Dependency(\.apiCache)
        var apiCache

        return apiCache.storagePath(id: self, server: server)
    }
}
