import Dependencies
import Foundation
import Tagged

// Five fields, because that is what /api/ui_settings/ sends and one type decoding both endpoints is
// worth more than eight properties nothing reads. /api/users/ still returns the rest; the decoder
// ignores them. Restoring one is additive if a screen ever needs it.
public struct User: Codable, Equatable, Hashable, Identifiable, Sendable {
    public typealias Id = Tagged<User, Int>

    public let groups: [Group.Id]

    public let id: User.Id

    public let isStaff: Bool

    public let isSuperuser: Bool

    public let username: String

    public init(
        groups: [Group.Id],
        id: User.Id,
        isStaff: Bool,
        isSuperuser: Bool,
        username: String
    ) {
        self.groups = groups
        self.id = id
        self.isStaff = isStaff
        self.isSuperuser = isSuperuser
        self.username = username
    }
}

extension User: Comparable {
    public static func < (lhs: User, rhs: User) -> Bool {
        lhs.username < rhs.username
    }
}

extension User: CustomStringConvertible {
    public var description: String {
        username
    }
}

public extension User {

    static func testValue(
        groups: [Group.Id] = [],
        id: User.Id = 1,
        isStaff: Bool = true,
        isSuperuser: Bool = true,
        username: String = "admin"
    ) -> Self {
        .init(
            groups: groups,
            id: id,
            isStaff: isStaff,
            isSuperuser: isSuperuser,
            username: username
        )
    }
}

public extension User.Id {

    func get(_ server: Server) -> User? {
        @Dependency(\.apiCache)
        var apiCache

        return apiCache.user(id: self, server: server)
    }
}
