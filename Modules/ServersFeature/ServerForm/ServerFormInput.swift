import ApiInterface
import Dependencies
import Foundation
import IdentifiedCollections

public struct ServerFormInput: Equatable, Sendable {

    public var alias: String

    public var code: String?

    public var headers: IdentifiedArrayOf<HTTPHeader>

    public var id: String

    public var password: String

    public var url: URL

    public var username: String
}

extension ServerFormInput {

    var isValid: Bool {
        [
            alias,
            id,
            password,
            url.host ?? "",
            username
        ].allSatisfy { !$0.isEmpty }
    }

    var server: Server {
        .init(
            alias: alias,
            headers: headers.filter { !$0.name.trimmingCharacters(in: .whitespaces).isEmpty },
            id: id,
            username: username,
            url: url
        )
    }
}

public extension ServerFormInput {
    static var empty: ServerFormInput {
        @Dependency(\.uuid)
        var uuid

        return .init(
            alias: "",
            headers: [
                HTTPHeader(id: uuid().uuidString, name: "Accept", value: "application/json; version=10")
            ],
            id: uuid().uuidString,
            password: "",
            url: .empty,
            username: ""
        )
    }
}

extension ServerFormInput {
    static func testValue(
        alias: String = "dev",
        code: String? = nil,
        headers: IdentifiedArrayOf<HTTPHeader> = [],
        id: String = "71A73DC6-74A7-4707-A6D9-873D3B2DE9C4",
        password: String = "T0PS3CR3T!!123",
        url: URL = .testValue(),
        username: String = "admin"
    ) -> Self {
        .init(
            alias: alias,
            code: code,
            headers: headers,
            id: id,
            password: password,
            url: url,
            username: username
        )
    }
}
