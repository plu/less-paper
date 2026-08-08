import Foundation

public struct GetStoragePathsInput: Codable, Equatable, Sendable {

    public let url: URL?

    public init(
        url: URL? = nil
    ) {
        self.url = url
    }
}

public extension GetStoragePathsInput {

    static func testValue(
        url: URL? = nil
    ) -> Self {
        .init(
            url: url
        )
    }
}
