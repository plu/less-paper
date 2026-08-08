import Dependencies
import Foundation
import Tagged

public struct User: Codable, Equatable, Hashable, Identifiable, Sendable {
    public typealias Id = Tagged<User, Int>

    public let dateJoined: Date

    public let email: String

    public let firstName: String

    public let groups: [Group.Id]

    public let id: User.Id

    @SkipUnknownValues
    public var inheritedPermissions: [InheritedPermission]

    public let isActive: Bool

    public let isMfaEnabled: Bool

    public let isStaff: Bool

    public let isSuperuser: Bool

    public let lastName: String

    @SkipUnknownValues
    public var userPermissions: [Permission]

    public let username: String

    public init(
        dateJoined: Date,
        email: String,
        firstName: String,
        groups: [Group.Id],
        id: User.Id,
        inheritedPermissions: [InheritedPermission],
        isActive: Bool,
        isMfaEnabled: Bool,
        isStaff: Bool,
        isSuperuser: Bool,
        lastName: String,
        userPermissions: [Permission],
        username: String
    ) {
        self.dateJoined = dateJoined
        self.email = email
        self.firstName = firstName
        self.groups = groups
        self.id = id
        self.inheritedPermissions = inheritedPermissions
        self.isActive = isActive
        self.isMfaEnabled = isMfaEnabled
        self.isStaff = isStaff
        self.isSuperuser = isSuperuser
        self.lastName = lastName
        self.userPermissions = userPermissions
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
        dateJoined: Date = Date.distantPast,
        email: String = "john@doe.com",
        firstName: String = "John",
        groups: [Group.Id] = [],
        id: User.Id = 1,
        inheritedPermissions: [InheritedPermission] = [],
        isActive: Bool = true,
        isMfaEnabled: Bool = true,
        isStaff: Bool = true,
        isSuperuser: Bool = true,
        lastName: String = "Doe",
        userPermissions: [Permission] = [],
        username: String = "admin"
    ) -> Self {
        .init(
            dateJoined: dateJoined,
            email: email,
            firstName: firstName,
            groups: groups,
            id: id,
            inheritedPermissions: inheritedPermissions,
            isActive: isActive,
            isMfaEnabled: isMfaEnabled,
            isStaff: isStaff,
            isSuperuser: isSuperuser,
            lastName: lastName,
            userPermissions: userPermissions,
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
