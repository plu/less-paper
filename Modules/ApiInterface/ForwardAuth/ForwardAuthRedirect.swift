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

    // Where the login sheet starts: paperless itself, not `url`. A proxy may bind its login to the
    // client that was bounced - mod_auth_openidc fingerprints the User-Agent into its state - and
    // the bounced client was URLSession, not the web view. Starting here makes the web view take
    // its own bounce. ui_settings because it is a GET under /api, behind the same proxy rules as
    // every API request.
    public var signInURL: URL {
        server.url.appending(path: "api/ui_settings/")
    }

    // The proxy has let the web view through once it is delivered back to signInURL, whatever
    // paperless answers there: a 401 is gate-only mode asking for its own login next. Any other
    // response from the server's host - a proxy's callback, or the error it answers one with - is
    // still part of the login. So is a 3xx at signInURL - the proxy bouncing it, not paperless
    // answering - and a 5xx, which is the proxy or paperless failing: closing on it would replay
    // every parked request into the same failure.
    public func isSignInComplete(_ response: URLResponse) -> Bool {
        guard let responseURL = response.url,
              let statusCode = (response as? HTTPURLResponse)?.statusCode,
              !(300 ..< 400).contains(statusCode),
              statusCode < 500
        else {
            return false
        }

        return responseURL.host() == signInURL.host()
            && responseURL.port == signInURL.port
            && responseURL.path() == signInURL.path()
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
