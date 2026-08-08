import Foundation

public struct GetTokenInput: Encodable, Equatable, Sendable {

    public let code: String?

    public let password: String

    public let username: String

    public init(
        code: String?,
        password: String,
        username: String
    ) {
        self.code = code
        self.password = password
        self.username = username
    }
}

public extension GetTokenInput {

    static func testValue(
        code: String? = nil,
        password: String = "T0PS3CR3T!!123",
        username: String = "admin"
    ) -> Self {
        .init(
            code: code,
            password: password,
            username: username
        )
    }
}
