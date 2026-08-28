import Foundation

public struct ForwardAuthRedirect: Equatable, Identifiable, Sendable {

    public let server: Server

    public let url: URL

    // Redirects are one-per-server at a time (the reducer guards on that), so the server id is
    // the stable identity.
    public var id: String { server.id }

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
