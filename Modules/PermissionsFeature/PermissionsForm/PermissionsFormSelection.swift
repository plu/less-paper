import ApiInterface
import Foundation

struct PermissionsFormSelection: Equatable, Sendable {

    struct Permissions: Equatable, Sendable {

        var groups: Set<Group> = []

        var users: Set<User> = []
    }

    var change: Permissions = .init()

    var owner: User?

    var view: Permissions = .init()

    var apiValue: (owner: User?, permissions: ApiInterface.Permissions) {
        (
            owner,
            .init(
                change: .init(
                    groups: change.groups.map(\.id),
                    users: change.users.map(\.id)
                ),
                view: .init(
                    groups: view.groups.map(\.id),
                    users: view.users.map(\.id)
                )
            )
        )
    }
}
