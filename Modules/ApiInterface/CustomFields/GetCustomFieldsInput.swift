import Foundation

public struct GetCustomFieldsInput: Codable, Equatable, Sendable {

    public let url: URL?

    public init(
        url: URL? = nil
    ) {
        self.url = url
    }
}

public extension GetCustomFieldsInput {

    static func testValue(
        url: URL? = nil
    ) -> Self {
        .init(
            url: url
        )
    }
}
