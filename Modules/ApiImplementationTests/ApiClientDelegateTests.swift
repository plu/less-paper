@testable import ApiImplementation

import ApiInterface
import AsyncAlgorithms
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

    // Naming a version before negotiating one cannot be made safe: a server outside the range the
    // guess belongs to answers 406, and a 406 carries no X-Api-Version to learn from — so the
    // client that guessed wrong never gets a successful response to correct itself with, and stays
    // stuck on every request. Saying nothing lets the server answer with its own version, which
    // `validateResponse` then stores.
    @Test
    func willSendRequest_omitsTheVersionUntilOneHasBeenNegotiated() async throws {
        let server = Server.testValue(headers: [], id: "un-negotiated")
        let delegate = ApiClientDelegate(server: server)
        var request = URLRequest(url: server.url.appending(path: "/api/documents/"))

        try await delegate.client(APIClient(baseURL: server.url), willSendRequest: &request)

        #expect(request.value(forHTTPHeaderField: "Accept") == nil)
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
        var request = URLRequest(url: server.url.appending(path: "/api/documents/"))

        try await delegate.client(APIClient(baseURL: server.url), willSendRequest: &request)

        #expect(request.value(forHTTPHeaderField: "Accept") == "application/json; version=9")
    }

    // /api/token/ is unauthenticated and returns nothing versioned, but a server that does not
    // speak the version we ask for answers 406 — demanding one here fails the login outright,
    // before the probe ever gets to tell the user the server is too old.
    @Test
    func willSendRequest_omitsTheVersionFromTheTokenRequest() async throws {
        let server = Server.testValue(headers: [])
        let delegate = ApiClientDelegate(server: server)
        var request = URLRequest(url: server.url.appending(path: "/api/token/"))
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        try await delegate.client(APIClient(baseURL: server.url), willSendRequest: &request)

        #expect(request.value(forHTTPHeaderField: "Accept") == "application/json")
    }

    // The probe cannot name a version it has not negotiated yet: a server that rejects the guess
    // answers 406, and that response carries no X-Api-Version to negotiate from.
    @Test
    func willSendRequest_omitsTheVersionWhenTheDelegateDoesNotSendOne() async throws {
        let server = Server.testValue(headers: [])
        let delegate = ApiClientDelegate(server: server, sendsApiVersion: false)
        var request = URLRequest(url: server.url.appending(path: "/api/ui_settings/"))
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        try await delegate.client(APIClient(baseURL: server.url), willSendRequest: &request)

        #expect(request.value(forHTTPHeaderField: "Accept") == "application/json")
    }

    @Test
    func willSendRequest_usesTheNegotiatedVersion() async throws {
        let server = Server.testValue(headers: [])
        @Shared(.apiVersion(server))
        var apiVersion: Int?
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
        var apiVersion: Int?

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
        var apiVersion: Int?

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
        var apiVersion: Int?
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
        var apiVersion: Int?
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

    // Remote-user mode stores no token: the proxy injects a trusted identity, and paperless
    // takes it. Sending Authorization: Token <empty> is worse than no header at all.
    @Test
    func willSendRequest_omitsAuthorizationWhenThereIsNoToken() async throws {
        let server = Server.testValue()
        let delegate = ApiClientDelegate(server: server)
        var request = URLRequest(url: server.url.appending(path: "/api/documents/"))

        try await withDependencies {
            $0.authenticationProvider.getToken = { _ in nil }
        } operation: {
            try await delegate.client(APIClient(baseURL: server.url), willSendRequest: &request)
        }

        #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
    }

    // Authelia's ForwardAuth answers 401 with a Location; Caddy's forward_auth passes it through.
    // 401 is not a redirect status, so URLSession never treats this as one - validateResponse is
    // the only place that can name it as a bounce.
    @Test
    func validateResponse_401WithForeignLocation_throwsForwardAuthRequired() throws {
        let server = Server.testValue(url: URL(string: "https://paperless.example.com")!)
        let delegate = ApiClientDelegate(server: server)
        let response = HTTPURLResponse(
            url: URL(string: "https://paperless.example.com/api/documents/")!,
            statusCode: 401,
            httpVersion: nil,
            headerFields: ["Location": "https://auth.example.com/login"]
        )!

        do {
            try delegate.client(
                APIClient(baseURL: server.url),
                validateResponse: response,
                data: Data(),
                task: URLSession.shared.dataTask(with: URLRequest(url: response.url!))
            )
            Issue.record("expected ForwardAuthError to be thrown")
        } catch let error as ForwardAuthError {
            #expect(error == .required(URL(string: "https://auth.example.com/login")!))
        }
    }

    // Every other proxy answers with a real 3xx, which ApiSessionDelegate refused - the task then
    // completes with the 3xx itself, and this test covers that branch.
    @Test
    func validateResponse_302WithForeignLocation_throwsForwardAuthRequired() throws {
        let server = Server.testValue(url: URL(string: "https://paperless.example.com")!)
        let delegate = ApiClientDelegate(server: server)
        let response = HTTPURLResponse(
            url: URL(string: "https://paperless.example.com/api/documents/")!,
            statusCode: 302,
            httpVersion: nil,
            headerFields: ["Location": "https://auth.example.com/login"]
        )!

        do {
            try delegate.client(
                APIClient(baseURL: server.url),
                validateResponse: response,
                data: Data(),
                task: URLSession.shared.dataTask(with: URLRequest(url: response.url!))
            )
            Issue.record("expected ForwardAuthError to be thrown")
        } catch let error as ForwardAuthError {
            #expect(error == .required(URL(string: "https://auth.example.com/login")!))
        }
    }

    // A 401 with no Location is an ordinary unauthorized - a stale token, a wrong password.
    // Opening a browser for that would be worse than reporting it.
    @Test
    func validateResponse_401WithoutLocation_isNotABounce() throws {
        let server = Server.testValue()
        let delegate = ApiClientDelegate(server: server)
        let response = HTTPURLResponse(
            url: server.url.appending(path: "/api/documents/"),
            statusCode: 401,
            httpVersion: nil,
            headerFields: nil
        )!
        let body = try JSONEncoder().encode(["detail": "Invalid token"])

        do {
            try delegate.client(
                APIClient(baseURL: server.url),
                validateResponse: response,
                data: body,
                task: URLSession.shared.dataTask(with: URLRequest(url: response.url!))
            )
            Issue.record("expected an error to be thrown")
        } catch is ForwardAuthError {
            Issue.record("a 401 without Location must not raise a forward-auth login")
        } catch {
            // Expected: the ordinary ApiError.
        }
    }

    // A 3xx pointing back to the same host is not a bounce - even though the delegate would have
    // followed it, so this branch only triggers if validateResponse ever sees one directly.
    @Test
    func validateResponse_sameHostLocation_isNotABounce() throws {
        let server = Server.testValue(url: URL(string: "https://paperless.example.com")!)
        let delegate = ApiClientDelegate(server: server)
        let response = HTTPURLResponse(
            url: URL(string: "https://paperless.example.com/api/documents/")!,
            statusCode: 302,
            httpVersion: nil,
            headerFields: ["Location": "https://paperless.example.com/api/documents/?page=2"]
        )!

        do {
            try delegate.client(
                APIClient(baseURL: server.url),
                validateResponse: response,
                data: Data(),
                task: URLSession.shared.dataTask(with: URLRequest(url: response.url!))
            )
            Issue.record("expected an error to be thrown")
        } catch is ForwardAuthError {
            Issue.record("a same-host redirect must not raise a forward-auth login")
        } catch {
            // Expected: the ordinary unacceptableStatusCode error.
        }
    }

    @Test
    func shouldRetry_waitsForFinishForItsOwnServer() async throws {
        let server = Server.testValue(id: "waiter")
        let delegate = ApiClientDelegate(server: server)
        let channel = AsyncChannel<ForwardAuthEvent>()

        let result = await withDependencies {
            $0.forwardAuthChannel = channel
        } operation: {
            async let retry = delegate.client(
                APIClient(baseURL: server.url),
                shouldRetry: URLSession.shared.dataTask(with: URLRequest(url: server.url)),
                error: ForwardAuthError.required(URL(string: "https://auth.example.com/login")!),
                attempts: 1
            )

            // A finish for a different server must not release this waiter.
            await channel.send(.finish(ForwardAuthRedirect(
                server: .testValue(id: "someone-else"),
                url: URL(string: "https://auth.example.com/login")!
            )))
            try? await Task.sleep(for: .milliseconds(50))

            await channel.send(.finish(ForwardAuthRedirect(
                server: server,
                url: URL(string: "https://auth.example.com/login")!
            )))

            return try? await retry
        }

        #expect(result == true)
    }

    // A cancelled sign-in must NOT retry the parked request - otherwise the popup dismisses,
    // shouldRetry replays, a new bounce arrives, and the popup loops forever.
    @Test
    func shouldRetry_returnsFalseWhenCancelledForItsOwnServer() async throws {
        let server = Server.testValue(id: "waiter")
        let delegate = ApiClientDelegate(server: server)
        let channel = AsyncChannel<ForwardAuthEvent>()

        let result = await withDependencies {
            $0.forwardAuthChannel = channel
        } operation: {
            async let retry = delegate.client(
                APIClient(baseURL: server.url),
                shouldRetry: URLSession.shared.dataTask(with: URLRequest(url: server.url)),
                error: ForwardAuthError.required(URL(string: "https://auth.example.com/login")!),
                attempts: 1
            )

            await channel.send(.cancelled(ForwardAuthRedirect(
                server: server,
                url: URL(string: "https://auth.example.com/login")!
            )))

            return try? await retry
        }

        #expect(result == false)
    }

    @Test
    func shouldRetry_returnsFalseForAnyOtherError() async throws {
        let server = Server.testValue()
        let delegate = ApiClientDelegate(server: server)

        let result = try await delegate.client(
            APIClient(baseURL: server.url),
            shouldRetry: URLSession.shared.dataTask(with: URLRequest(url: server.url)),
            error: URLError(.notConnectedToInternet),
            attempts: 1
        )

        #expect(result == false)
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
