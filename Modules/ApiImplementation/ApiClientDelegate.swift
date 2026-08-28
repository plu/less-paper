import ApiInterface
import AsyncAlgorithms
import Dependencies
import Foundation
import Get
import Logging
import SwiftSharing

struct ApiClientDelegate: Sendable {

    let server: Server

    // Cleared by the version probe, which cannot name a version it has not negotiated yet.
    var sendsApiVersion = true

    @Dependency(\.authenticationProvider)
    private var authenticationProvider

    @Dependency(\.log)
    private var log
}

extension ApiClientDelegate: Get.APIClientDelegate {

    func client(_ client: APIClient, willSendRequest request: inout URLRequest) async throws {
        // Paperless writes absolute URLs into its responses — `next` among them — built from what it
        // believes its own origin to be. Behind a reverse proxy missing PAPERLESS_PROXY_SSL_HEADER
        // or the X-Forwarded headers, that is an internal http:// origin. Following one redirects to
        // the real origin, and URLSession drops the Authorization header across that change, so a
        // correctly authenticated request comes back 401. The configured server is authoritative.
        request.url = request.url?.movedToOrigin(of: server.url)

        let isTokenRequest = request.url?.path().contains("/api/token/") == true

        // /api/token/ is unauthenticated and returns nothing versioned, but a server that does not
        // speak the version we ask for answers 406 — demanding one here fails the login outright,
        // before the probe ever gets to tell the user the server is too old.
        if sendsApiVersion, !isTokenRequest {
            @Shared(.apiVersion(server))
            var apiVersion: Int?

            if let apiVersion {
                request.setValue("application/json; version=\(apiVersion)", forHTTPHeaderField: "Accept")
            }
        }

        for header in server.headers {
            request.setValue(header.value, forHTTPHeaderField: header.name)
        }

        guard !isTokenRequest else {
            return
        }

        guard let token = try await authenticationProvider.getToken(server: server) else {
            // Remote-user mode: a forward-auth proxy injects a trusted identity header and
            // paperless takes it. The cookie authenticates the request, so no Authorization is
            // sent - a bare `Token ` with nothing after it would be rejected.
            return
        }
        request.setValue("Token \(token)", forHTTPHeaderField: "Authorization")
    }

    func client(_ client: APIClient, validateResponse response: HTTPURLResponse, data: Data, task: URLSessionTask) throws {
        // Every request passes through here, so this is the one place that has to remember to log.
        // The alternative was 26 call sites each remembering, which is how logging rots.
        logResponse(response, data: data, task: task)

        storeAdvertisedApiVersion(from: response)

        // Any non-2xx with a Location leaving the server's host is a proxy telling us to sign in.
        // Both bounce shapes end up here: the 401+Location one directly, and the genuine 3xx one
        // after ApiSessionDelegate refused to follow it into the completion.
        if !(200 ..< 300).contains(response.statusCode),
           let location = response.value(forHTTPHeaderField: "Location"),
           let redirectURL = URL(string: location),
           let redirectHost = redirectURL.host(),
           let serverHost = server.url.host(),
           redirectHost != serverHost {
            let redirect = ForwardAuthRedirect(server: server, url: redirectURL)
            Task {
                @Dependency(\.forwardAuthChannel)
                var channel

                await channel.send(.redirect(redirect))
            }
            throw ForwardAuthError.required(redirectURL)
        }

        if (400 ..< 500).contains(response.statusCode) {
            let error = try JSONDecoder().decode(ApiError.self, from: data)
            throw error
        }
        guard (200 ..< 300).contains(response.statusCode) else {
            throw APIError.unacceptableStatusCode(response.statusCode)
        }
    }

    func client(
        _ client: APIClient,
        shouldRetry task: URLSessionTask,
        error: any Error,
        attempts: Int
    ) async throws -> Bool {
        guard case ForwardAuthError.required = error else {
            return false
        }

        // Every parked request awaits the same event. Ten concurrent bounces at launch produce
        // one login, and each request replays as soon as it finishes. The comparison is on
        // server.id so a login for one server does not release requests parked against another.
        @Dependency(\.forwardAuthChannel)
        var channel

        for await event in channel {
            if case let .finish(redirect) = event, redirect.server.id == server.id {
                return true
            }
        }

        return false
    }

    /// One line per *failed* request: what was asked, of where, and what came back.
    ///
    /// Successful requests are not recorded. A working app makes hundreds of them, and a log that
    /// reports them all buries the two lines that matter under the ones that do not - which is what
    /// happened the first time this shipped.
    ///
    /// No duration: URLSessionTask does not carry one without collecting metrics through a separate
    /// delegate, and the response size answers the question timing usually stands in for - whether
    /// a call returned far more than expected.
    private func logResponse(_ response: HTTPURLResponse, data: Data, task: URLSessionTask) {
        guard !(200 ..< 300).contains(response.statusCode) else {
            return
        }

        let method = task.originalRequest?.httpMethod ?? "?"
        let path = task.originalRequest?.url.map(LogRedaction.redact) ?? "?"

        log.error("\(method) \(path) → \(response.statusCode) (\(data.count) bytes)", category: .api)
    }

    func client<T>(_ client: APIClient, decoderForRequest request: Request<T>) -> JSONDecoder? {
        let decoder = LoggingJSONDecoder(path: request.url.map(LogRedaction.redact) ?? "?")
        decoder.configureForApi()
        return decoder
    }

    private func storeAdvertisedApiVersion(from response: HTTPURLResponse) {
        guard let header = response.value(forHTTPHeaderField: "X-Api-Version"),
              let advertised = Int(header),
              let negotiated = try? ApiVersion.negotiated(from: advertised)
        else {
            return
        }

        @Shared(.apiVersion(server))
        var apiVersion: Int?

        guard apiVersion != negotiated else {
            return
        }
        $apiVersion.withLock { $0 = negotiated }
    }
}
