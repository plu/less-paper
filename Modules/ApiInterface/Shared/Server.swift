import Dependencies
import Foundation
import IdentifiedCollections

public struct Server: Codable, Equatable, Hashable, Identifiable, Sendable {

    public let alias: String

    public let headers: IdentifiedArrayOf<HTTPHeader>

    public let id: String

    public let username: String

    public let url: URL

    public init(
        alias: String,
        headers: IdentifiedArrayOf<HTTPHeader> = [],
        id: String,
        username: String,
        url: URL
    ) {
        self.alias = alias
        self.headers = headers
        self.id = id
        self.username = username
        self.url = url
    }
}

public extension Server {

    static func testValue(
        alias: String = "dev",
        headers: IdentifiedArrayOf<HTTPHeader> = [],
        id: String = "71A73DC6-74A7-4707-A6D9-873D3B2DE9C4",
        username: String = "admin",
        url: URL = .testValue()
    ) -> Self {
        .init(
            alias: alias,
            headers: headers,
            id: id,
            username: username,
            url: url
        )
    }
}

extension Server: Comparable {
    public static func < (lhs: Server, rhs: Server) -> Bool {
        lhs.alias < rhs.alias
    }
}

extension Server: CustomStringConvertible {
    public var description: String {
        alias
    }
}
