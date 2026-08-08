import Foundation
import Tagged

public struct GetPermissionsOutput: Codable, Equatable, Sendable {

    public let owner: User.Id?

    public let permissions: Permissions?

    public init(
        owner: User.Id? = nil,
        permissions: Permissions? = nil
    ) {
        self.owner = owner
        self.permissions = permissions
    }
}

public extension GetPermissionsOutput {

    static func testValue(
        owner: User.Id? = 42,
        permissions: Permissions? = .testValue()
    ) -> Self {
        .init(
            owner: owner,
            permissions: permissions
        )
    }
}
