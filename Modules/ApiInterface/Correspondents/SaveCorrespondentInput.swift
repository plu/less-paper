import Foundation
import Tagged

public struct SaveCorrespondentInput: Codable, Equatable, Sendable {

    public var isInsensitive: Bool

    public var match: String

    public var matchingAlgorithm: MatchingAlgorithm

    public var name: String

    public var owner: Clearable<User.Id>?

    public var setPermissions: Permissions?

    public init(
        isInsensitive: Bool = true,
        match: String = "",
        matchingAlgorithm: MatchingAlgorithm = .automatic,
        name: String,
        owner: Clearable<User.Id>? = nil,
        setPermissions: Permissions? = nil
    ) {
        self.isInsensitive = isInsensitive
        self.match = match
        self.matchingAlgorithm = matchingAlgorithm
        self.name = name
        self.owner = owner
        self.setPermissions = setPermissions
    }
}

public extension SaveCorrespondentInput {

    init(
        setPermissions: Permissions? = nil,
        correspondent: Correspondent?
    ) {
        self.init(
            isInsensitive: correspondent?.isInsensitive ?? true,
            match: correspondent?.match ?? "",
            matchingAlgorithm: correspondent?.matchingAlgorithm ?? .automatic,
            name: correspondent?.name ?? "",
            owner: correspondent?.owner.ifPresent { .value($0) },
            setPermissions: setPermissions
        )
    }
}

public extension SaveCorrespondentInput {

    static func testValue(
        isInsensitive: Bool = true,
        match: String = "",
        matchingAlgorithm: MatchingAlgorithm = .automatic,
        name: String = "Test Correspondent",
        owner: Clearable<User.Id>? = .value(1),
        setPermissions: Permissions = .testValue()
    ) -> Self {
        .init(
            isInsensitive: isInsensitive,
            match: match,
            matchingAlgorithm: matchingAlgorithm,
            name: name,
            owner: owner,
            setPermissions: setPermissions
        )
    }
}
