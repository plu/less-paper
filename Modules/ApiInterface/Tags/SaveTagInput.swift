import Foundation
import Tagged

public struct SaveTagInput: Codable, Equatable, Sendable {

    public var color: String

    public var isInboxTag: Bool

    public var isInsensitive: Bool

    public var match: String

    public var matchingAlgorithm: MatchingAlgorithm

    public var name: String

    public var owner: Clearable<User.Id>?

    public var setPermissions: Permissions?

    public init(
        color: String,
        isInboxTag: Bool,
        isInsensitive: Bool = true,
        match: String = "",
        matchingAlgorithm: MatchingAlgorithm = .automatic,
        name: String,
        owner: Clearable<User.Id>? = nil,
        setPermissions: Permissions? = nil
    ) {
        self.color = color
        self.isInboxTag = isInboxTag
        self.isInsensitive = isInsensitive
        self.match = match
        self.matchingAlgorithm = matchingAlgorithm
        self.name = name
        self.owner = owner
        self.setPermissions = setPermissions
    }
}

public extension SaveTagInput {

    init(
        setPermissions: Permissions? = nil,
        tag: Tag?
    ) {
        self.init(
            color: tag?.color ?? "#006A68",
            isInboxTag: tag?.isInboxTag ?? false,
            isInsensitive: tag?.isInsensitive ?? true,
            match: tag?.match ?? "",
            matchingAlgorithm: tag?.matchingAlgorithm ?? .automatic,
            name: tag?.name ?? "",
            owner: tag?.owner.ifPresent { .value($0) },
            setPermissions: setPermissions
        )
    }
}

public extension SaveTagInput {

    static func testValue(
        color: String = "#F7CE46",
        isInboxTag: Bool = true,
        isInsensitive: Bool = true,
        match: String = "",
        matchingAlgorithm: MatchingAlgorithm = .automatic,
        name: String = "Inbox",
        owner: Clearable<User.Id>? = .value(1),
        setPermissions: Permissions = .testValue()
    ) -> Self {
        .init(
            color: color,
            isInboxTag: isInboxTag,
            isInsensitive: isInsensitive,
            match: match,
            matchingAlgorithm: matchingAlgorithm,
            name: name,
            owner: owner,
            setPermissions: setPermissions
        )
    }
}
