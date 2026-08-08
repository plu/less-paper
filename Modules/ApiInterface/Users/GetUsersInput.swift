import Foundation

public struct GetUsersInput: Codable, Equatable, Sendable {

    public let url: URL?

    public init(
        url: URL? = nil
    ) {
        self.url = url
    }
}

public extension GetUsersInput {

    static func testValue(
        url: URL? = nil
    ) -> Self {
        .init(
            url: url
        )
    }
}
