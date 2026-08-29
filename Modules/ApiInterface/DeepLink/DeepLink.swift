import Foundation

// A link into the app: which server it names, and what to open there.
//
// Parsing and building live in one type on purpose. Two functions in two modules drift the first
// time the path changes, and the failure - links the app writes but cannot read - is invisible
// until someone taps one.
public struct DeepLink: Equatable, Sendable {

    public enum Route: Equatable, Sendable {
        case documentDetail(Document.Id)
    }

    // What new links are written with. `atlp` is still parsed because the shipping app wrote it and
    // those links outlive the codebase that made them, but it is never advertised. It stays
    // registered for its other job, the OIDC callback.
    public static let scheme = "lesspaper"

    public static let legacyScheme = "atlp"

    public let host: String

    public let port: Int?

    // Whatever the path carries before the route, which is the server's own base path. Empty for a
    // server hosted at the root.
    public let prefix: String

    public let route: Route

    public init(
        host: String,
        port: Int? = nil,
        prefix: String = "",
        route: Route
    ) {
        self.host = host
        self.port = port
        self.prefix = prefix
        self.route = route
    }
}

public extension DeepLink {

    init?(url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let scheme = components.scheme?.lowercased(),
              scheme == Self.scheme || scheme == Self.legacyScheme,
              let host = components.host,
              !host.isEmpty,
              let parsed = Self.parse(path: components.path)
        else {
            return nil
        }

        self.init(
            host: host,
            port: components.port,
            prefix: parsed.prefix,
            route: parsed.route
        )
    }

    func resolves(to server: Server) -> Bool {
        guard let components = URLComponents(url: server.url, resolvingAgainstBaseURL: false),
              let serverHost = components.host
        else {
            return false
        }

        return serverHost.lowercased() == host.lowercased()
            && components.port == port
            && Self.normalized(path: components.path) == prefix
    }

    static func appURL(server: Server, route: Route) -> URL? {
        url(scheme: Self.scheme, server: server, route: route)
    }

    static func webURL(server: Server, route: Route) -> URL? {
        url(scheme: server.url.scheme ?? "https", server: server, route: route)
    }
}

private extension DeepLink {

    // Matched from the end, which is what lets a server hosted under a subpath work without the
    // parser knowing any server exists: the prefix is whatever the match leaves behind.
    static func parse(path: String) -> (prefix: String, route: Route)? {
        var segments = path.split(separator: "/", omittingEmptySubsequences: true).map(String.init)

        guard segments.count >= 3,
              segments.removeLast() == "details",
              let id = Int(segments.removeLast()),
              segments.removeLast() == "documents"
        else {
            return nil
        }

        let prefix = segments.isEmpty ? "" : "/" + segments.joined(separator: "/")

        return (prefix, .documentDetail(Document.Id(rawValue: id)))
    }

    static func normalized(path: String) -> String {
        var path = path

        while path.hasSuffix("/") {
            path.removeLast()
        }

        return path
    }

    static func url(scheme: String, server: Server, route: Route) -> URL? {
        guard var components = URLComponents(url: server.url, resolvingAgainstBaseURL: false) else {
            return nil
        }

        switch route {
        case let .documentDetail(id):
            components.path = normalized(path: components.path) + "/documents/\(id.rawValue)/details"
        }

        components.scheme = scheme

        return components.url
    }
}
