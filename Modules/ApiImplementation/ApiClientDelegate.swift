import ApiInterface
import Dependencies
import Foundation
import Get

struct ApiClientDelegate: Sendable {

    let server: Server

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

        request.setValue("application/json; version=10", forHTTPHeaderField: "Accept")

        for header in server.headers {
            request.setValue(header.value, forHTTPHeaderField: header.name)
        }

        guard request.url?.path().contains("/api/token/") == false else {
            return
        }

        let token = try await authenticationProvider.getToken(server: server)
        request.setValue("Token \(token)", forHTTPHeaderField: "Authorization")
    }

    func client(_ client: APIClient, validateResponse response: HTTPURLResponse, data: Data, task: URLSessionTask) throws {
        if (400 ..< 500).contains(response.statusCode) {
            let error = try JSONDecoder().decode(ApiError.self, from: data)
            throw error
        }
        guard (200 ..< 300).contains(response.statusCode) else {
            throw APIError.unacceptableStatusCode(response.statusCode)
        }
    }
}
