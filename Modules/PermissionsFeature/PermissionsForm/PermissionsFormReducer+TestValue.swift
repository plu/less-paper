import ApiInterface
import Foundation
import IdentifiedCollections

extension PermissionsFormReducer.State {

    static func testValue(
        options: PermissionsFormOptions = .testValue(),
        selection: PermissionsFormSelection = .testValue(),
        server: Server = .testValue(),
        type: PermissionsType = .tag(id: 1)
    ) -> Self {
        .init(
            options: options,
            selection: selection,
            server: server,
            type: type
        )
    }
}

extension PermissionsFormOptions {
    static func testValue(
        groups: [Group] = [.testValue()],
        users: [User] = [.testValue()]
    ) -> Self {
        .init(
            groups: IdentifiedArray(uniqueElements: groups),
            users: IdentifiedArray(uniqueElements: users)
        )
    }
}

extension PermissionsFormSelection {
    static func testValue(
        change: Permissions = .testValue(),
        owner: User? = .testValue(),
        view: Permissions = .testValue()
    ) -> Self {
        .init(
            change: change,
            owner: owner,
            view: view
        )
    }
}

extension PermissionsFormSelection.Permissions {
    static func testValue(
        groups: Set<Group> = [.testValue()],
        users: Set<User> = [.testValue()]
    ) -> Self {
        .init(
            groups: groups,
            users: users
        )
    }
}
