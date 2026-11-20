@testable import ApiInterface

import Foundation
import Testing
import TestSupport

@Suite(
    .testDependencies()
)
struct ShareLinkTests {

    @Test
    func decode_withExpiration() throws {
        let json = """
        {"id":3,"created":"2026-11-18T10:00:00.000000+01:00","expiration":"2026-11-25T10:00:00+01:00","slug":"aB3x9Q"}
        """

        let link = try JSONDecoder.apiDecoder.decode(ShareLink.self, from: Data(json.utf8))

        #expect(link.id == 3)
        #expect(link.slug == "aB3x9Q")
        #expect(link.expiration != nil)
    }

    @Test
    func decode_withoutExpiration() throws {
        let json = """
        {"id":3,"created":"2026-11-18T10:00:00.000000+01:00","expiration":null,"slug":"aB3x9Q"}
        """

        let link = try JSONDecoder.apiDecoder.decode(ShareLink.self, from: Data(json.utf8))

        #expect(link.expiration == nil)
    }

    @Test
    func url_rootServer() {
        let server = Server.testValue(url: URL(string: "https://paperless.example.com")!)

        #expect(
            ShareLink.testValue(slug: "aB3x9Q").url(server: server)?.absoluteString
                == "https://paperless.example.com/share/aB3x9Q"
        )
    }

    @Test
    func url_subpathServer() {
        let server = Server.testValue(url: URL(string: "https://example.com/paperless")!)

        #expect(
            ShareLink.testValue(slug: "aB3x9Q").url(server: server)?.absoluteString
                == "https://example.com/paperless/share/aB3x9Q"
        )
    }

    @Test
    func url_trailingSlash() {
        let server = Server.testValue(url: URL(string: "https://example.com/paperless/")!)

        #expect(
            ShareLink.testValue(slug: "aB3x9Q").url(server: server)?.absoluteString
                == "https://example.com/paperless/share/aB3x9Q"
        )
    }
}
