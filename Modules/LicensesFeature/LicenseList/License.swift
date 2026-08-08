import Foundation

public struct License: Equatable, Sendable {

    public let content: String

    public let name: String

    public init(
        content: String,
        name: String
    ) {
        self.content = content
        self.name = name
    }
}

extension License: Hashable, Identifiable {
    public var id: String { name }
}

public extension License {

    static func testValue(
        content: String = "# License\nMIT License",
        name: String = "The Composable Architecture"
    ) -> Self {
        .init(
            content: content,
            name: name
        )
    }
}
