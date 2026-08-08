import Foundation

public struct SaveUserInput: Codable, Equatable, Sendable {

    public var email: String

    public var firstName: String

    public var groups: [Group.Id]

    public var isActive: Bool

    public var isStaff: Bool

    public var isSuperuser: Bool

    public var lastName: String

    public var password: String?

    public var userPermissions: [Permission]

    public var username: String

    public init(
        email: String,
        firstName: String = "",
        groups: [Group.Id] = [],
        isActive: Bool = true,
        isStaff: Bool = false,
        isSuperuser: Bool = false,
        lastName: String = "",
        password: String? = nil,
        userPermissions: [Permission] = [],
        username: String
    ) {
        self.email = email
        self.firstName = firstName
        self.groups = groups
        self.isActive = isActive
        self.isStaff = isStaff
        self.isSuperuser = isSuperuser
        self.lastName = lastName
        self.password = password
        self.userPermissions = userPermissions
        self.username = username
    }
}

public extension SaveUserInput {

    init(user: User?) {
        self.init(
            email: user?.email ?? "",
            firstName: user?.firstName ?? "",
            groups: user?.groups ?? [],
            isActive: user?.isActive ?? true,
            isStaff: user?.isStaff ?? false,
            isSuperuser: user?.isSuperuser ?? false,
            lastName: user?.lastName ?? "",
            password: nil,
            userPermissions: user?.userPermissions ?? [],
            username: user?.username ?? ""
        )
    }
}

public extension SaveUserInput {

    static func testValue(
        email: String = "jane@doe.com",
        firstName: String = "Jane",
        groups: [Group.Id] = [],
        isActive: Bool = true,
        isStaff: Bool = true,
        isSuperuser: Bool = true,
        lastName: String = "Doe",
        password: String? = "T0PS3CR3T!!123",
        userPermissions: [Permission] = [],
        username: String = "jdoe"
    ) -> Self {
        .init(
            email: email,
            firstName: firstName,
            groups: groups,
            isActive: isActive,
            isStaff: isStaff,
            isSuperuser: isSuperuser,
            lastName: lastName,
            password: password,
            userPermissions: userPermissions,
            username: username
        )
    }
}
