@testable import ApiImplementation

import ApiInterface
import Dependencies
import Foundation
import Get
import SwiftSharing
import Testing
import TestSupport

@Suite(
    .dependencies()
)
struct ApiClientDelegateTests {

    @Test
    func willSendRequest_fallsBackToTheMinimumSupportedVersion() async throws {
        let server = Server.testValue(headers: [])
        let delegate = ApiClientDelegate(server: server)
        var request = URLRequest(url: server.url.appending(path: "/api/token/"))

        try await delegate.client(APIClient(baseURL: server.url), willSendRequest: &request)

        #expect(request.value(forHTTPHeaderField: "Accept") == "application/json; version=9")
    }

    // A Paperless behind a reverse proxy without PAPERLESS_PROXY_SSL_HEADER believes it is serving
    // plain HTTP and writes http:// absolute URLs into its responses, `next` among them. Following
    // one redirects to HTTPS, and URLSession drops the Authorization header across a scheme change,
    // so a correctly authenticated client gets a 401.
    @Test
    func willSendRequest_upgradesAnHttpUrlToTheServersScheme() async throws {
        let server = Server.testValue(url: URL(string: "https://paperless.example.com")!)
        let delegate = ApiClientDelegate(server: server)
        var request = URLRequest(url: URL(string: "http://paperless.example.com/api/token/?page=2")!)

        try await delegate.client(APIClient(baseURL: server.url), willSendRequest: &request)

        #expect(request.url?.absoluteString == "https://paperless.example.com/api/token/?page=2")
    }

    @Test
    func willSendRequest_rewritesAnInternalHostAndPortToTheServers() async throws {
        let server = Server.testValue(url: URL(string: "https://paperless.example.com")!)
        let delegate = ApiClientDelegate(server: server)
        var request = URLRequest(url: URL(string: "http://paperless:8000/api/token/?page=3")!)

        try await delegate.client(APIClient(baseURL: server.url), willSendRequest: &request)

        #expect(request.url?.absoluteString == "https://paperless.example.com/api/token/?page=3")
    }

    @Test
    func willSendRequest_keepsAPathPrefixWhenRewritingTheOrigin() async throws {
        let server = Server.testValue(url: URL(string: "https://example.com/paperless")!)
        let delegate = ApiClientDelegate(server: server)
        var request = URLRequest(url: URL(string: "http://paperless:8000/paperless/api/token/?page=2")!)

        try await delegate.client(APIClient(baseURL: server.url), willSendRequest: &request)

        #expect(request.url?.absoluteString == "https://example.com/paperless/api/token/?page=2")
    }

    @Test
    func willSendRequest_leavesAMatchingUrlUnchanged() async throws {
        let server = Server.testValue(url: URL(string: "https://paperless.example.com:8443")!)
        let delegate = ApiClientDelegate(server: server)
        var request = URLRequest(url: URL(string: "https://paperless.example.com:8443/api/token/")!)

        try await delegate.client(APIClient(baseURL: server.url), willSendRequest: &request)

        #expect(request.url?.absoluteString == "https://paperless.example.com:8443/api/token/")
    }

    @Test
    func willSendRequest_customAcceptHeaderOverridesDefault() async throws {
        let server = Server.testValue(headers: [
            .testValue(id: "1", name: "Accept", value: "application/json; version=9")
        ])
        let delegate = ApiClientDelegate(server: server)
        var request = URLRequest(url: server.url.appending(path: "/api/token/"))

        try await delegate.client(APIClient(baseURL: server.url), willSendRequest: &request)

        #expect(request.value(forHTTPHeaderField: "Accept") == "application/json; version=9")
    }

    @Test
    func willSendRequest_usesTheNegotiatedVersion() async throws {
        let server = Server.testValue(headers: [])
        @Shared(.apiVersion(server))
        var apiVersion: Int
        $apiVersion.withLock { $0 = 10 }

        let delegate = ApiClientDelegate(server: server)
        var request = URLRequest(url: server.url.appending(path: "/api/documents/"))

        try await delegate.client(APIClient(baseURL: server.url), willSendRequest: &request)

        #expect(request.value(forHTTPHeaderField: "Accept") == "application/json; version=10")
    }

    @Test
    func validateResponse_storesTheAdvertisedVersion() throws {
        let server = Server.testValue()
        @Shared(.apiVersion(server))
        var apiVersion: Int

        let delegate = ApiClientDelegate(server: server)
        try delegate.client(
            APIClient(baseURL: server.url),
            validateResponse: .testValue(server: server, headers: ["X-Api-Version": "10"]),
            data: Data(),
            task: URLSession.shared.dataTask(with: server.url)
        )

        #expect(apiVersion == 10)
    }

    @Test
    func validateResponse_clampsAServerAheadOfTheClient() throws {
        let server = Server.testValue()
        @Shared(.apiVersion(server))
        var apiVersion: Int

        let delegate = ApiClientDelegate(server: server)
        try delegate.client(
            APIClient(baseURL: server.url),
            validateResponse: .testValue(server: server, headers: ["X-Api-Version": "12"]),
            data: Data(),
            task: URLSession.shared.dataTask(with: server.url)
        )

        #expect(apiVersion == ApiVersion.clientMaximum)
    }

    // /api/token/ is unauthenticated, and ApiVersionMiddleware only sets the header for
    // authenticated users, so an absent header is routine and must not clobber a good value.
    @Test
    func validateResponse_leavesTheCacheAloneWhenTheHeaderIsAbsent() throws {
        let server = Server.testValue()
        @Shared(.apiVersion(server))
        var apiVersion: Int
        $apiVersion.withLock { $0 = 10 }

        let delegate = ApiClientDelegate(server: server)
        try delegate.client(
            APIClient(baseURL: server.url),
            validateResponse: .testValue(server: server, headers: [:]),
            data: Data(),
            task: URLSession.shared.dataTask(with: server.url)
        )

        #expect(apiVersion == 10)
    }

    // A version below the floor is not written to the cache — the probe is what rejects such a
    // server, and a passive read must never lower the app below what it can decode.
    @Test
    func validateResponse_ignoresAVersionBelowTheFloor() throws {
        let server = Server.testValue()
        @Shared(.apiVersion(server))
        var apiVersion: Int
        $apiVersion.withLock { $0 = 10 }

        let delegate = ApiClientDelegate(server: server)
        try delegate.client(
            APIClient(baseURL: server.url),
            validateResponse: .testValue(server: server, headers: ["X-Api-Version": "6"]),
            data: Data(),
            task: URLSession.shared.dataTask(with: server.url)
        )

        #expect(apiVersion == 10)
    }
}

private extension HTTPURLResponse {

    static func testValue(
        server: Server,
        statusCode: Int = 200,
        headers: [String: String]
    ) -> HTTPURLResponse {
        HTTPURLResponse(
            url: server.url,
            statusCode: statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: headers
        )!
    }
}
