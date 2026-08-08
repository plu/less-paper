import Foundation
import Tagged

public struct Permissions: Codable, Equatable, Sendable {

    public struct Values: Codable, Equatable, Sendable {

        public let groups: [Group.Id]

        public let users: [User.Id]

        public init(
            groups: [Group.Id] = [],
            users: [User.Id] = []
        ) {
            self.groups = groups
            self.users = users
        }
    }

    public let change: Values

    public let view: Values

    public init(
        change: Values = .init(),
        view: Values = .init()
    ) {
        self.change = change
        self.view = view
    }
}

public extension Permissions.Values {

    static func testValue(
        groups: [Group.Id] = [],
        users: [User.Id] = []
    ) -> Self {
        .init(
            groups: groups,
            users: users
        )
    }
}

public extension Permissions {

    static func testValue(
        change: Values = .testValue(
            groups: [1, 2, 3],
            users: [4, 5, 6]
        ),
        view: Values = .testValue(
            groups: [7, 8, 9],
            users: [10, 11, 12]
        )
    ) -> Self {
        .init(
            change: change,
            view: view
        )
    }
}
