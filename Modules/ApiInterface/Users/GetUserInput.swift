import Foundation
import Tagged

public struct GetUserInput: Codable, Equatable, Sendable {

    public let id: User.Id

    public init(
        id: User.Id
    ) {
        self.id = id
    }
}

public extension GetUserInput {

    static func testValue(
        id: User.Id = 1
    ) -> Self {
        .init(
            id: id
        )
    }
}
