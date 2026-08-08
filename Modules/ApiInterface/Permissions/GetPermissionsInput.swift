import Foundation
import Tagged

public struct GetPermissionsInput: Codable, Equatable, Sendable {

    public let type: PermissionsType

    public init(
        type: PermissionsType
    ) {
        self.type = type
    }
}

public extension GetPermissionsInput {

    static func testValue(
        type: PermissionsType = .tag(id: 1)
    ) -> Self {
        .init(
            type: type
        )
    }
}
