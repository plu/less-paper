import Foundation

public struct GetDocumentTypesInput: Codable, Equatable, Sendable {

    public let url: URL?

    public init(
        url: URL? = nil
    ) {
        self.url = url
    }
}

public extension GetDocumentTypesInput {

    static func testValue(
        url: URL? = nil
    ) -> Self {
        .init(
            url: url
        )
    }
}
