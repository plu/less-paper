import ApiInterface
import Dependencies
import Foundation
import Get
import SwiftSharing

struct ApiClientDelegate: Sendable {

    let server: Server

    // Cleared by the version probe, which cannot name a version it has not negotiated yet.
    var sendsApiVersion = true

    @Dependency(\.authenticationProvider)
    private var authenticationProvider
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
            var apiVersion: Int

            request.setValue("application/json; version=\(apiVersion)", forHTTPHeaderField: "Accept")
        }

        for header in server.headers {
            request.setValue(header.value, forHTTPHeaderField: header.name)
        }

        guard !isTokenRequest else {
            return
        }

        let token = try await authenticationProvider.getToken(server: server)
        request.setValue("Token \(token)", forHTTPHeaderField: "Authorization")
    }

    func client(_ client: APIClient, validateResponse response: HTTPURLResponse, data: Data, task: URLSessionTask) throws {
        storeAdvertisedApiVersion(from: response)

        if (400 ..< 500).contains(response.statusCode) {
            let error = try JSONDecoder().decode(ApiError.self, from: data)
            throw error
        }
        guard (200 ..< 300).contains(response.statusCode) else {
            throw APIError.unacceptableStatusCode(response.statusCode)
        }
    }

    private func storeAdvertisedApiVersion(from response: HTTPURLResponse) {
        guard let header = response.value(forHTTPHeaderField: "X-Api-Version"),
              let advertised = Int(header),
              let negotiated = try? ApiVersion.negotiated(from: advertised)
        else {
            return
        }

        @Shared(.apiVersion(server))
        var apiVersion: Int

        guard apiVersion != negotiated else {
            return
        }
        $apiVersion.withLock { $0 = negotiated }
    }
}
