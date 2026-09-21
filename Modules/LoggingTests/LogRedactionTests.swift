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

    @Test(arguments: ["page", "ordering", "custom_field_query", "tags__id__all", "document_type__id"])
    func test_isSensitive_keepsDiagnosticNames(name: String) {
        #expect(!LogRedaction.isSensitive(name))
    }

    // `query` is the search term on /api/search/ and the advanced-search filter on
    // /api/documents/ (FilterRuleType.fulltextQuery), so it is user content on both — as often a
    // person's name as a word.
    @Test(arguments: ["query", "term"])
    func test_isSensitive_catchesSearchTerms(name: String) {
        #expect(LogRedaction.isSensitive(name))
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

    // Free text, because that is how the leak got out: an error description carrying a URL the call
    // site never touched. The path stays - it is the question that failed - and the rest of the
    // sentence is left alone.
    @Test
    func test_redactMessage_dropsTheHostAndKeepsThePath() {
        let redacted = LogRedaction.redact(message: "next ASN failed: https://paperless.example.com/api/documents/next_asn/ refused")

        #expect(redacted == "next ASN failed: /api/documents/next_asn/ refused")
    }

    @Test(arguments: [
        "GET /api/documents/?page=2 200 4 kB",
        "cache updated in 1.8s · 34 tags",
        "scene phase: background",
    ])
    func test_redactMessage_leavesMessagesWithoutAURLAlone(message: String) {
        #expect(LogRedaction.redact(message: message) == message)
    }

    // A failed /api/search/ would otherwise write the user's search term into the file they share
    // with support, and a term is as often a person's name as it is a word.
    @Test
    func redactUrl_redactsSearchTerms() throws {
        let url = try #require(URL(string: "https://example.com/api/search/?query=Mustermann"))

        #expect(LogRedaction.redact(url) == "/api/search/?query=<redacted>")
    }

    @Test
    func redactUrl_redactsAutocompleteTerms() throws {
        let url = try #require(URL(string: "https://example.com/api/search/autocomplete/?term=Muster"))

        #expect(LogRedaction.redact(url) == "/api/search/autocomplete/?term=<redacted>")
    }

    // The containment list would have taken `custom_field_query` with it, and which filter was
    // applied when a request failed is the whole point of that log line.
    @Test
    func redactUrl_keepsCustomFieldQuery() throws {
        let url = try #require(
            URL(string: "https://example.com/api/documents/?custom_field_query=exists")
        )

        #expect(LogRedaction.redact(url).contains("custom_field_query=exists"))
        #expect(LogRedaction.redact(url).contains(LogRedaction.placeholder) == false)
    }
}
