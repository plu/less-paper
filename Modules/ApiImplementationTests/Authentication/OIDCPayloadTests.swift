@testable import ApiImplementation

import Foundation
import Testing
import TestSupport

@Suite(
    .testDependencies()
)
struct OIDCPayloadTests {

    @Test
    func test_discovery_decodesTheEndpoints() throws {
        let discovery = try JSONDecoder().decode(
            Discovery.self,
            from: Data(OIDCStub.discoveryBody.utf8)
        )

        #expect(discovery.authorizationEndpoint.absoluteString == "https://sso.example.com/authorize")
        #expect(discovery.tokenEndpoint.absoluteString == "https://sso.example.com/token")
    }

    @Test
    func test_providerToken_decodesTheIdToken() throws {
        let token = try JSONDecoder().decode(
            ProviderToken.self,
            from: Data(#"{"id_token": "the-id-token"}"#.utf8)
        )

        #expect(token.idToken == "the-id-token")
    }

    @Test
    func test_providerToken_toleratesAMissingIdToken() throws {
        let token = try JSONDecoder().decode(
            ProviderToken.self,
            from: Data(#"{}"#.utf8)
        )

        #expect(token.idToken == nil)
    }

    @Test
    func test_oauthFailure_decodesTheProviderError() throws {
        let failure = try JSONDecoder().decode(
            OAuthFailure.self,
            from: Data(#"{"error": "invalid_request", "error_description": "Redirect URI is not registered"}"#.utf8)
        )

        #expect(failure.error == "invalid_request")
        #expect(failure.errorDescription == "Redirect URI is not registered")
    }

    @Test
    func test_tokenResponse_decodesBothTokens() throws {
        let response = try JSONDecoder().decode(
            TokenResponse.self,
            from: Data(#"{"meta": {"access_token": "access", "session_token": "session"}}"#.utf8)
        )

        #expect(response.meta.accessToken == "access")
        #expect(response.meta.sessionToken == "session")
    }

    @Test
    func test_headlessFailure_summaryIsNilWithoutErrors() throws {
        let decoded = try JSONDecoder().decode(
            HeadlessFailure.self,
            from: Data(#"{}"#.utf8)
        )

        #expect(decoded.summary == nil)
    }

    @Test
    func test_headlessFailure_summaryIsNilForAnEmptyList() throws {
        let decoded = try JSONDecoder().decode(
            HeadlessFailure.self,
            from: Data(#"{"errors": []}"#.utf8)
        )

        #expect(decoded.summary == nil)
    }

    @Test
    func test_headlessFailure_summaryNamesTheField() throws {
        let decoded = try JSONDecoder().decode(
            HeadlessFailure.self,
            from: Data(#"{"errors": [{"code": "token_invalid", "message": "Incorrect authentication credentials.", "param": "token"}]}"#
                .utf8)
        )

        #expect(decoded.summary == "Incorrect authentication credentials. (token)")
    }

    @Test
    func test_headlessFailure_summaryJoinsSeveralErrors() throws {
        let decoded = try JSONDecoder().decode(
            HeadlessFailure.self,
            from: Data(
                #"{"errors": [{"code": "a", "message": "First.", "param": null}, {"code": "b", "message": "Second.", "param": "code"}]}"#
                    .utf8
            )
        )

        #expect(decoded.summary == "First. Second. (code)")
    }
}
