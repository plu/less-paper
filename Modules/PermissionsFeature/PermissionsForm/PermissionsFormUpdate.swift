import ApiInterface
import Foundation

public struct PermissionsFormUpdate: Equatable {

    public let owner: Clearable<User>?

    public let permissions: Permissions

    public init(
        owner: Clearable<User>?,
        permissions: Permissions
    ) {
        self.owner = owner
        self.permissions = permissions
    }
}

public extension PermissionsFormUpdate {

    static func testValue(
        owner: Clearable<User>? = .value(.testValue()),
        permissions: Permissions = .testValue()
    ) -> Self {
        .init(
            owner: owner,
            permissions: permissions
        )
    }
}
