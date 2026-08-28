import Foundation

public struct Credentials: Equatable, Sendable {

    /// Absent for a server signed in through a provider: there is no password to keep, and a type
    /// that can say so beats storing an empty string and hoping nothing reads it.
    public let password: String?

    public let token: String

    public init(
        password: String?,
        token: String
    ) {
        self.password = password
        self.token = token
    }
}

public extension Credentials {

    static func testValue(
        password: String = "T0PS3CR3T!!123",
        token: String = "c0ff33"
    ) -> Self {
        .init(
            password: password,
            token: token
        )
    }
}
