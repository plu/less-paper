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
