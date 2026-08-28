@testable import ApiImplementation

import Foundation
import Testing

@Suite
struct ProviderTokenRequestTests {

    // allauth answers a flat body with 400 and two errors that both name `token` - "This field is
    // required" and "Invalid token" - which reads like the id_token was rejected rather than never
    // looked for. The shape is pinned here because only a real server can catch it otherwise.
    @Test
    func test_encoded_nestsTheCredentialUnderToken() throws {
        let request = ProviderTokenRequest(
            process: "login",
            provider: "authentik",
            token: .init(clientId: "the-client-id", idToken: "the-id-token")
        )

        let data = try JSONEncoder().encode(request)
        let json = try #require(
            try JSONSerialization.jsonObject(with: data) as? [String: Any]
        )

        #expect(json["provider"] as? String == "authentik")
        #expect(json["process"] as? String == "login")
        // Not at the top level, which is what was sent the first time.
        #expect(json["id_token"] == nil)
        #expect(json["client_id"] == nil)

        let token = try #require(json["token"] as? [String: Any])
        #expect(token["id_token"] as? String == "the-id-token")
        #expect(token["client_id"] as? String == "the-client-id")
    }
}
