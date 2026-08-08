import Foundation
import Tagged

public struct SaveStoragePathInput: Codable, Equatable, Sendable {

    public var isInsensitive: Bool

    public var match: String

    public var matchingAlgorithm: MatchingAlgorithm

    public var name: String

    public var owner: Clearable<User.Id>?

    public var path: String

    public var setPermissions: Permissions?

    public init(
        isInsensitive: Bool = true,
        match: String = "",
        matchingAlgorithm: MatchingAlgorithm = .automatic,
        name: String,
        owner: Clearable<User.Id>? = nil,
        path: String,
        setPermissions: Permissions? = nil
    ) {
        self.isInsensitive = isInsensitive
        self.match = match
        self.matchingAlgorithm = matchingAlgorithm
        self.name = name
        self.owner = owner
        self.path = path
        self.setPermissions = setPermissions
    }
}

public extension SaveStoragePathInput {

    init(
        setPermissions: Permissions? = nil,
        storagePath: StoragePath?
    ) {
        self.init(
            isInsensitive: storagePath?.isInsensitive ?? true,
            match: storagePath?.match ?? "",
            matchingAlgorithm: storagePath?.matchingAlgorithm ?? .automatic,
            name: storagePath?.name ?? "",
            owner: storagePath?.owner.ifPresent { .value($0) },
            path: storagePath?.path ?? "",
            setPermissions: setPermissions
        )
    }
}

public extension SaveStoragePathInput {

    static func testValue(
        isInsensitive: Bool = true,
        match: String = "",
        matchingAlgorithm: MatchingAlgorithm = .automatic,
        name: String = "Test StoragePath",
        owner: Clearable<User.Id>? = .value(1),
        path: String = "/home/paperless/test-storagepath",
        setPermissions: Permissions = .testValue()
    ) -> Self {
        .init(
            isInsensitive: isInsensitive,
            match: match,
            matchingAlgorithm: matchingAlgorithm,
            name: name,
            owner: owner,
            path: path,
            setPermissions: setPermissions
        )
    }
}
