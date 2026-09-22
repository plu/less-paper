import Foundation

public struct GlobalSearchInput: Codable, Equatable, Sendable {

    public let query: String

    public init(query: String) {
        self.query = query
    }
}

public extension GlobalSearchInput {

    static func testValue(query: String = "manual") -> Self {
        .init(query: query)
    }
}
