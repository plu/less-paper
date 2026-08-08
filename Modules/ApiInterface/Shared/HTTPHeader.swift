import Foundation

public struct HTTPHeader: Codable, Equatable, Hashable, Identifiable, Sendable {

    public let id: String

    public var name: String

    public var value: String

    public init(
        id: String,
        name: String,
        value: String
    ) {
        self.id = id
        self.name = name
        self.value = value
    }
}

public extension HTTPHeader {
    static func testValue(
        id: String = "9E2B1B2E-2F0B-4C9E-8B0E-1B2E2F0B4C9E",
        name: String = "Accept",
        value: String = "application/json; version=10"
    ) -> Self {
        .init(id: id, name: name, value: value)
    }
}
