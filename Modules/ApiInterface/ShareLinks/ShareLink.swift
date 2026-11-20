import Foundation
import Tagged

public struct ShareLink: Codable, Equatable, Hashable, Identifiable, Sendable {

    public typealias Id = Tagged<ShareLink, Int>

    public enum FileVersion: String, Codable, Sendable {
        case archive
        case original
    }

    public let created: Date

    public let expiration: Date?

    public let id: Id

    public let slug: String

    public init(
        created: Date,
        expiration: Date?,
        id: Id,
        slug: String
    ) {
        self.created = created
        self.expiration = expiration
        self.id = id
        self.slug = slug
    }
}

public extension ShareLink {

    // Appended to the server's path rather than replacing it, so a server hosted under a subpath
    // keeps its prefix, and a trailing slash does not leave an empty segment behind.
    func url(server: Server) -> URL? {
        guard var components = URLComponents(url: server.url, resolvingAgainstBaseURL: false) else {
            return nil
        }

        var path = components.path
        while path.hasSuffix("/") {
            path.removeLast()
        }
        components.path = path + "/share/\(slug)"

        return components.url
    }

    static func testValue(
        created: Date = .testValue(),
        expiration: Date? = nil,
        id: Id = 1,
        slug: String = "aB3x9Q"
    ) -> Self {
        .init(
            created: created,
            expiration: expiration,
            id: id,
            slug: slug
        )
    }
}
