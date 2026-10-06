@testable import ApiImplementation

import ApiInterface
import Dependencies
import Foundation
import Testing
import TestSupport

@Suite(
    .testDependencies()
)
struct OIDCLoginFlowTests {

    // MARK: Step 2, discovery

    @Test
    func test_discover_readsTheAdvertisedEndpoints() async throws {
        let session = OIDCSession(session: OIDCStubProtocol.session())

        try await withStub(.providers) {
            let discovery = try await session.discover(provider: .testValue())

            #expect(discovery.authorizationEndpoint.absoluteString == "https://sso.example.com/authorize")
            #expect(discovery.tokenEndpoint.absoluteString == "https://sso.example.com/token")
        }
    }

    @Test
    func test_discover_throwsWhenTheConfigurationIsMissing() async throws {
        let session = OIDCSession(session: OIDCStubProtocol.session())
        let provider = OIDCProvider.testValue(
            configurationURL: URL(string: "https://sso.example.com/config")!
        )

        await #expect(throws: OIDCError.missingConfigurationURL(provider: "Authentik")) {
            try await withStub(.notFound) {
                _ = try await session.discover(provider: provider)
            }
        }
    }

    // MARK: Step 5, the callback

    @Test
    func test_login_rejectsACallbackCarryingNoCode() async throws {
        let session = OIDCSession(session: OIDCStubProtocol.session())

        await withDependencies {
            $0.webAuthentication.authenticate = { url, _ in
                var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
                components.queryItems = components.queryItems?.filter { $0.name == "state" }
                return components.url!
            }
        } operation: {
            await #expect(throws: OIDCError.missingCode) {
                try await withStub(.providers) {
                    _ = try await session.login(provider: .testValue(), url: .testValue())
                }
            }
        }
    }

    // MARK: Steps 6 and 7, the exchange and the redeem

    @Test
    func test_login_returnsThePaperlessToken() async throws {
        let session = OIDCSession(session: OIDCStubProtocol.session())

        try await withDependencies {
            $0.webAuthentication.authenticate = callbackReturningCode()
        } operation: {
            try await withStub(.tokenSuccess) {
                let result = try await session.login(provider: .testValue(), url: .testValue())

                #expect(result == .token("the-access-token"))
            }
        }
    }

    @Test
    func test_login_returnsSecondFactorWhenPaperlessAsksForOne() async throws {
        let session = OIDCSession(session: OIDCStubProtocol.session())

        try await withDependencies {
            $0.webAuthentication.authenticate = callbackReturningCode()
        } operation: {
            try await withStub(.tokenSecondFactor) {
                let result = try await session.login(provider: .testValue(), url: .testValue())

                #expect(result == .secondFactorRequired)
            }
        }
    }

    @Test
    func test_login_reportsWhatPaperlessRejected() async throws {
        let session = OIDCSession(session: OIDCStubProtocol.session())

        try await withDependencies {
            $0.webAuthentication.authenticate = callbackReturningCode()
        } operation: {
            try await withStub(.tokenRejected) {
                let error = await #expect(throws: OIDCError.self) {
                    _ = try await session.login(provider: .testValue(), url: .testValue())
                }

                #expect(error == .serverRejectedIdentity(
                    status: 400,
                    reason: "Incorrect authentication credentials. (token)"
                ))
            }
        }
    }

    @Test
    func test_exchange_namesAnUnregisteredRedirectURI() async throws {
        let session = OIDCSession(session: OIDCStubProtocol.session())

        try await withStub(.tokenRedirectNotRegistered) {
            let error = await #expect(throws: OIDCError.self) {
                _ = try await session.exchange(
                    code: "the-code",
                    discovery: .testValue(),
                    provider: .testValue(),
                    pkce: PKCE()
                )
            }

            #expect(error == .redirectURINotRegistered(uri: OIDCSession.redirectURI))
        }
    }

    @Test
    func test_exchange_reportsAProviderError() async throws {
        let session = OIDCSession(session: OIDCStubProtocol.session())

        try await withStub(.notFound) {
            let error = await #expect(throws: OIDCError.self) {
                _ = try await session.exchange(
                    code: "the-code",
                    discovery: .testValue(),
                    provider: .testValue(),
                    pkce: PKCE()
                )
            }

            #expect(error == .tokenExchangeFailed(reason: "status 404"))
        }
    }

    @Test
    func test_exchange_reportsAMissingIdToken() async throws {
        let session = OIDCSession(session: OIDCStubProtocol.session())

        try await withStub(.tokenWithoutIdToken) {
            let error = await #expect(throws: OIDCError.self) {
                _ = try await session.exchange(
                    code: "the-code",
                    discovery: .testValue(),
                    provider: .testValue(),
                    pkce: PKCE()
                )
            }

            #expect(error == .tokenExchangeFailed(reason: "the provider returned no id_token"))
        }
    }

    // MARK: The second factor

    @Test
    func test_confirmSecondFactor_completesThePendingLogin() async throws {
        let session = OIDCSession(session: OIDCStubProtocol.session())

        try await withDependencies {
            $0.webAuthentication.authenticate = callbackReturningCode()
        } operation: {
            try await withStub(.tokenSecondFactor) {
                #expect(try await session.login(provider: .testValue(), url: .testValue()) == .secondFactorRequired)

                let token = try await session.confirmSecondFactor(code: "123456", url: .testValue())

                #expect(token == "the-access-token")
            }
        }
    }

    @Test
    func test_confirmSecondFactor_reportsWhatPaperlessRejected() async throws {
        let session = OIDCSession(session: OIDCStubProtocol.session())
        await session.setPendingSessionToken("the-session-token")

        try await withStub(.twoFactorRejected) {
            let error = await #expect(throws: OIDCError.self) {
                _ = try await session.confirmSecondFactor(code: "wrong", url: .testValue())
            }

            #expect(error == .serverRejectedIdentity(status: 400, reason: "Incorrect code. (code)"))
        }
    }

    @Test
    func test_confirmSecondFactor_throwsWhenNothingIsPending() async throws {
        let session = OIDCSession(session: OIDCStubProtocol.session())

        await #expect(throws: OIDCError.noSecondFactorPending) {
            _ = try await session.confirmSecondFactor(code: "123456", url: .testValue())
        }
    }

    // MARK: URL plumbing

    @Test
    func test_queryParameters_readsTheCallback() async {
        let session = OIDCSession(session: OIDCStubProtocol.session())

        let parameters = await session.queryParameters(
            of: URL(string: "atlp://oidc-callback?code=the-code&state=the-state")!
        )

        #expect(parameters == ["code": "the-code", "state": "the-state"])
    }

    // The state is the session's own anti-forgery value, so the stub answers whatever state the
    // authorization URL asked with rather than a canned one.
    private func callbackReturningCode() -> @Sendable (URL, String) async throws -> URL {
        { url, _ in
            let state = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "state" })?.value
            return URL(string: "atlp://oidc-callback?code=the-code&state=\(state ?? "")")!
        }
    }

    private func withStub(_ stub: OIDCStub, operation: () async throws -> Void) async throws {
        OIDCStubProtocol.current = stub
        defer { OIDCStubProtocol.current = nil }
        try await operation()
    }
}
