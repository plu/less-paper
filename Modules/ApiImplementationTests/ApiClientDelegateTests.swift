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
