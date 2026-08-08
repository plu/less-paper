import Foundation

public struct GetTokenOutput: Decodable, Equatable, Sendable {

    public let token: String

    public init(
        token: String
    ) {
        self.token = token
    }
}

public extension GetTokenOutput {

    static func testValue(
        token: String = "s3cr3t-c0ff33"
    ) -> Self {
        .init(
            token: token
        )
    }
}
