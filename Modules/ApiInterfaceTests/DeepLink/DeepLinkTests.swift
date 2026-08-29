import ApiInterface
import Foundation
import Testing

@Suite
struct DeepLinkTests {

    @Test
    func parsesTheAppScheme() throws {
        let link = try #require(DeepLink(url: URL(string: "lesspaper://paperless.example.com/documents/42/details")!))

        #expect(link.host == "paperless.example.com")
        #expect(link.port == nil)
        #expect(link.prefix == "")
        #expect(link.route == .documentDetail(42))
    }

    // Every link the shipping app ever wrote uses atlp, and those outlive the codebase that made
    // them: someone's note from a year ago has to keep working.
    @Test
    func parsesTheLegacyScheme() throws {
        let link = try #require(DeepLink(url: URL(string: "atlp://paperless.example.com/documents/42/details")!))

        #expect(link.route == .documentDetail(42))
    }

    @Test
    func rejectsAnyOtherScheme() {
        #expect(DeepLink(url: URL(string: "https://paperless.example.com/documents/42/details")!) == nil)
    }

    // The server's own path comes back as the prefix rather than having to be subtracted from the
    // match. The old app whole-matched the path and so never parsed a link to a server like this.
    @Test
    func keepsTheServersPathPrefix() throws {
        let link = try #require(DeepLink(url: URL(string: "lesspaper://example.com/paperless/documents/42/details")!))

        #expect(link.prefix == "/paperless")
        #expect(link.route == .documentDetail(42))
    }

    @Test
    func keepsThePort() throws {
        let link = try #require(DeepLink(url: URL(string: "lesspaper://example.com:8200/documents/42/details")!))

        #expect(link.port == 8200)
    }

    @Test
    func toleratesATrailingSlash() throws {
        let link = try #require(DeepLink(url: URL(string: "lesspaper://example.com/documents/42/details/")!))

        #expect(link.route == .documentDetail(42))
    }

    @Test
    func rejectsANonNumericId() {
        #expect(DeepLink(url: URL(string: "lesspaper://example.com/documents/abc/details")!) == nil)
    }

    @Test
    func rejectsAPathThatIsNotADocumentDetail() {
        #expect(DeepLink(url: URL(string: "lesspaper://example.com/documents/42")!) == nil)
        #expect(DeepLink(url: URL(string: "lesspaper://example.com/tags/42/details")!) == nil)
        #expect(DeepLink(url: URL(string: "lesspaper://example.com/oidc-callback")!) == nil)
    }

    @Test
    func resolvesAgainstTheServerItNames() throws {
        let server = Server.testValue(url: URL(string: "https://paperless.example.com")!)
        let link = try #require(DeepLink(url: URL(string: "lesspaper://paperless.example.com/documents/42/details")!))

        #expect(link.resolves(to: server))
    }

    @Test
    func doesNotResolveAcrossHostsPortsOrPrefixes() throws {
        let link = try #require(DeepLink(url: URL(string: "lesspaper://paperless.example.com:8200/paperless/documents/42/details")!))

        #expect(link.resolves(to: .testValue(url: URL(string: "https://elsewhere.example.com:8200/paperless")!)) == false)
        #expect(link.resolves(to: .testValue(url: URL(string: "https://paperless.example.com:9000/paperless")!)) == false)
        #expect(link.resolves(to: .testValue(url: URL(string: "https://paperless.example.com:8200/other")!)) == false)
        #expect(link.resolves(to: .testValue(url: URL(string: "https://paperless.example.com:8200/paperless")!)))
    }

    // A trailing slash on the configured server URL is the user's typing, not a different server.
    @Test
    func resolvesRegardlessOfATrailingSlashOnTheServer() throws {
        let link = try #require(DeepLink(url: URL(string: "lesspaper://example.com/paperless/documents/42/details")!))

        #expect(link.resolves(to: .testValue(url: URL(string: "https://example.com/paperless/")!)))
    }

    // Build and parse are one type so the two formats cannot drift: a link the app writes but
    // cannot read is invisible until someone taps one.
    @Test
    func roundTripsThroughTheAppURL() throws {
        for server in [
            Server.testValue(url: URL(string: "https://paperless.example.com")!),
            Server.testValue(url: URL(string: "https://example.com/paperless")!),
            Server.testValue(url: URL(string: "http://example.com:8200")!),
        ] {
            let url = try #require(DeepLink.appURL(server: server, route: .documentDetail(42)))
            let link = try #require(DeepLink(url: url))

            #expect(link.resolves(to: server))
            #expect(link.route == .documentDetail(42))
        }
    }

    @Test
    func appURLUsesTheAppScheme() throws {
        let server = Server.testValue(url: URL(string: "https://example.com/paperless")!)
        let url = try #require(DeepLink.appURL(server: server, route: .documentDetail(42)))

        #expect(url.absoluteString == "lesspaper://example.com/paperless/documents/42/details")
    }

    @Test
    func webURLKeepsTheServersOwnScheme() throws {
        let server = Server.testValue(url: URL(string: "http://example.com:8200")!)
        let url = try #require(DeepLink.webURL(server: server, route: .documentDetail(42)))

        #expect(url.absoluteString == "http://example.com:8200/documents/42/details")
    }
}
