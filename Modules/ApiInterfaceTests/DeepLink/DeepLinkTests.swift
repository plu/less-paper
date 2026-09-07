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

    @Test
    func parsesTheScanRoute() throws {
        let link = try #require(DeepLink(url: URL(string: "lesspaper://paperless.example.com/scan")!))

        #expect(link.host == "paperless.example.com")
        #expect(link.port == nil)
        #expect(link.prefix == "")
        #expect(link.route == .scan)
    }

    // The prefix is what identifies the server, so a scan link to a server under a subpath has to
    // hand it back intact. Losing it resolves the link to no server at all, and the user gets
    // "server not found" from a control they configured correctly.
    @Test
    func keepsTheServersPathPrefixOnAScanLink() throws {
        let link = try #require(DeepLink(url: URL(string: "lesspaper://example.com/paperless/scan")!))

        #expect(link.prefix == "/paperless")
        #expect(link.route == .scan)
    }

    @Test
    func toleratesATrailingSlashOnAScanLink() throws {
        let link = try #require(DeepLink(url: URL(string: "lesspaper://example.com/scan/")!))

        #expect(link.route == .scan)
    }

    @Test
    func resolvesAScanLinkAgainstTheServerItNames() throws {
        let server = Server.testValue(url: URL(string: "https://example.com/paperless")!)
        let link = try #require(DeepLink(url: URL(string: "lesspaper://example.com/paperless/scan")!))

        #expect(link.resolves(to: server))
    }

    @Test
    func appURLBuildsTheScanPath() throws {
        let server = Server.testValue(url: URL(string: "https://example.com/paperless")!)
        let url = try #require(DeepLink.appURL(server: server, route: .scan))

        #expect(url.absoluteString == "lesspaper://example.com/paperless/scan")
    }

    @Test
    func roundTripsAScanLink() throws {
        for server in [
            Server.testValue(url: URL(string: "https://paperless.example.com")!),
            Server.testValue(url: URL(string: "https://example.com/paperless")!),
            Server.testValue(url: URL(string: "http://example.com:8200")!),
        ] {
            let url = try #require(DeepLink.appURL(server: server, route: .scan))
            let link = try #require(DeepLink(url: url))

            #expect(link.resolves(to: server))
            #expect(link.route == .scan)
        }
    }

    // A server whose own path ends in "scan" is the case that would break a parser matching the
    // last segment without looking further: this must stay a document link, not become a scan.
    @Test
    func stillReadsADocumentLinkUnderAServerPathEndingInScan() throws {
        let link = try #require(DeepLink(url: URL(string: "lesspaper://example.com/scan/documents/42/details")!))

        #expect(link.prefix == "/scan")
        #expect(link.route == .documentDetail(42))
    }

    @Test
    func scanURLIsNilWithoutAServer() {
        #expect(DeepLink.scanURL(server: nil) == nil)
    }

    @Test
    func scanURLNamesTheServer() throws {
        let server = Server.testValue(url: URL(string: "https://example.com")!)
        let url = try #require(DeepLink.scanURL(server: server))

        #expect(url.absoluteString == "lesspaper://example.com/scan")
    }

    @Test
    func appLaunchURLUsesTheAppScheme() {
        #expect(DeepLink.appLaunchURL.scheme == DeepLink.scheme)
    }

    // This is the property the control actually depends on: without it, a control with no server
    // selected would hand `OpenURLIntent` a link that resolves to something instead of opening the
    // app plainly.
    @Test
    func appLaunchURLIsNotAParsableLink() {
        #expect(DeepLink(url: DeepLink.appLaunchURL) == nil)
    }
}
