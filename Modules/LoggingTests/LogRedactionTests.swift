@testable import Logging

import Foundation
import Testing

@Suite
struct LogRedactionTests {

    @Test(arguments: [
        "token",
        "auth_token",
        "Authorization",
        "api_key",
        "X-Api-Key",
        "password",
        "session_id",
        "client_secret",
        "signature",
        "cookie",
    ])
    func test_isSensitive_catchesCredentialNames(name: String) {
        #expect(LogRedaction.isSensitive(name))
    }

    @Test(arguments: ["page", "ordering", "query", "tags__id__all", "document_type__id"])
    func test_isSensitive_keepsDiagnosticNames(name: String) {
        #expect(!LogRedaction.isSensitive(name))
    }

    @Test
    func test_redact_removesTokenValueAndKeepsPagination() throws {
        let url = try #require(URL(string: "https://paperless.example.com/api/documents/?page=2&token=abc123secret"))

        let redacted = LogRedaction.redact(url)

        #expect(!redacted.contains("abc123secret"))
        #expect(redacted.contains("page=2"))
        #expect(redacted.contains(LogRedaction.placeholder))
    }

    @Test
    func test_redact_keepsThePathWhole() throws {
        let url = try #require(URL(string: "https://paperless.example.com/api/documents/42/download/"))

        #expect(LogRedaction.redact(url) == "/api/documents/42/download/")
    }

    @Test
    func test_redact_headersKeepsNamesAndNoValues() {
        let headers = [
            "Authorization": "Token abc123secret",
            "Content-Type": "application/json",
        ]

        let redacted = LogRedaction.redact(headers: headers)

        #expect(redacted == ["Authorization", "Content-Type"])
        #expect(!redacted.joined().contains("abc123secret"))
    }

    // The rule the OIDC line broke: a URL reaching the log through redact() never carries its host.
    @Test(arguments: [
        "https://paperless.example.com/api/documents/?page=2",
        "http://paperless.internal:8000/api/tags/",
        "https://docs.someones-surname.dev/api/auth/headless/app/v1/config",
    ])
    func test_redact_neverKeepsTheHost(address: String) throws {
        let url = try #require(URL(string: address))
        let host = try #require(url.host())

        #expect(!LogRedaction.redact(url).contains(host))
    }
}
