import Foundation

public struct ForwardAuthRedirect: Equatable, Sendable {

    public let server: Server

    public let url: URL

    public init(
        server: Server,
        url: URL
    ) {
        self.server = server
        self.url = url
    }
}

public extension ForwardAuthRedirect {

    static func testValue(
        server: Server = .testValue(),
        url: URL = .testValue()
    ) -> Self {
        .init(
            server: server,
            url: url
        )
    }
}
