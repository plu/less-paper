import Foundation

public struct SaveGroupInput: Codable, Equatable, Sendable {

    public var name: String

    public var permissions: [Permission]

    public init(
        name: String,
        permissions: [Permission]
    ) {
        self.name = name
        self.permissions = permissions
    }
}

public extension SaveGroupInput {

    static func testValue(
        name: String = "Admins",
        permissions: [Permission] = Permission.allCases
    ) -> Self {
        .init(
            name: name,
            permissions: permissions
        )
    }
}
