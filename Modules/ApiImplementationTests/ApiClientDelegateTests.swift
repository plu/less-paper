@testable import ApiImplementation

import ApiInterface
import Foundation
import Get
import Testing

@Suite
struct ApiClientDelegateTests {

    @Test
    func willSendRequest_setsDefaultVersion10AcceptHeader() async throws {
        let server = Server.testValue(headers: [])
        let delegate = ApiClientDelegate(server: server)
        var request = URLRequest(url: server.url.appending(path: "/api/token/"))

        try await delegate.client(APIClient(baseURL: server.url), willSendRequest: &request)

        #expect(request.value(forHTTPHeaderField: "Accept") == "application/json; version=10")
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
}
