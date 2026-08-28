@testable import ApiImplementation

import ApiInterface
import Dependencies
import Foundation
import Testing

@Suite
struct OIDCSessionTests {

    // MARK: Step 3, building the authorization URL

    @Test
    func test_authorizationURL_carriesTheChallengeAndNotTheVerifier() async {
        let session = OIDCSession(session: OIDCStubProtocol.session())
        let pkce = PKCE(verifier: "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk")

        let url = await session.authorizationURL(
            discovery: .testValue(),
            provider: .testValue(),
            pkce: pkce,
            state: "the-state"
        )
        let query = url.query() ?? ""

        #expect(query.contains("code_challenge=\(pkce.challenge)"))
        #expect(query.contains("code_challenge_method=S256"))
        // The whole point of PKCE: the verifier stays here until the exchange.
        #expect(!query.contains(pkce.verifier))
    }

    @Test
    func test_authorizationURL_asksForAnOpenIDScope() async {
        let session = OIDCSession(session: OIDCStubProtocol.session())

        let url = await session.authorizationURL(
            discovery: .testValue(),
            provider: .testValue(),
            pkce: PKCE(),
            state: "the-state"
        )

        // Without openid the provider runs a plain OAuth2 flow and returns no id_token, which is
        // the only thing paperless will accept.
        #expect(url.query()?.contains("scope=openid") == true)
    }

    // MARK: Step 1, reading the providers

    @Test
    func test_providers_readsWhatTheServerOffers() async throws {
        let session = OIDCSession(session: OIDCStubProtocol.session())

        try await withStub(.providers) {
            let providers = await session.providers(url: .testValue())

            #expect(providers.count == 1)
            #expect(providers.first?.id == "authentik")
            #expect(providers.first?.clientId == "the-client-id")
        }
    }

    @Test
    func test_providers_isEmptyWhenTheServerOffersNone() async throws {
        let session = OIDCSession(session: OIDCStubProtocol.session())

        try await withStub(.noProviders) {
            #expect(await session.providers(url: .testValue()).isEmpty)
        }
    }

    // A server that is not paperless, or is unreachable, must leave the password form working
    // rather than fail the whole screen.
    @Test
    func test_providers_isEmptyWhenTheServerIsNotPaperless() async throws {
        let session = OIDCSession(session: OIDCStubProtocol.session())

        try await withStub(.notFound) {
            #expect(await session.providers(url: .testValue()).isEmpty)
        }
    }

    // A provider with no client id cannot be used, so it must not become a button that fails when
    // tapped.
    @Test
    func test_providers_dropsOnesThatCannotBeUsed() async throws {
        let session = OIDCSession(session: OIDCStubProtocol.session())

        try await withStub(.unusableProvider) {
            #expect(await session.providers(url: .testValue()).isEmpty)
        }
    }

    // MARK: Step 5, the callback

    @Test
    func test_login_rejectsACallbackCarryingTheWrongState() async throws {
        let session = OIDCSession(session: OIDCStubProtocol.session())

        await withDependencies {
            $0.webAuthentication.authenticate = { _, _ in
                URL(string: "atlp://oidc-callback?code=the-code&state=not-the-state")!
            }
        } operation: {
            await #expect(throws: OIDCError.stateMismatch) {
                try await withStub(.providers) {
                    _ = try await session.login(provider: .testValue(), url: .testValue())
                }
            }
        }
    }

    @Test
    func test_login_rejectsAProviderTheServerDoesNotOffer() async throws {
        let session = OIDCSession(session: OIDCStubProtocol.session())
        let absent = OIDCProvider.testValue(id: "not-configured")

        await #expect(throws: OIDCError.unknownProvider(id: "not-configured")) {
            try await withStub(.providers) {
                _ = try await session.login(provider: absent, url: .testValue())
            }
        }
    }

    private func withStub(_ stub: OIDCStub, operation: () async throws -> Void) async throws {
        OIDCStubProtocol.current = stub
        defer { OIDCStubProtocol.current = nil }
        try await operation()
    }
}

extension Discovery {

    static func testValue() -> Self {
        .init(
            authorizationEndpoint: URL(string: "https://sso.example.com/authorize")!,
            tokenEndpoint: URL(string: "https://sso.example.com/token")!
        )
    }
}
