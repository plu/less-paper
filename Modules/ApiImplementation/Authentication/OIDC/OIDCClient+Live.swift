import ApiInterface
import Dependencies
import Foundation

extension OIDCClient: @retroactive DependencyKey {

    public static let liveValue = Self(
        providers: { url in await OIDCSession.shared.providers(url: url) },
        login: { provider, url in try await OIDCSession.shared.login(provider: provider, url: url) },
        confirmSecondFactor: { code, url in
            try await OIDCSession.shared.confirmSecondFactor(code: code, url: url)
        }
    )
}

/// The login, and the only thing it has to remember between calls.
///
/// An actor because the second factor arrives as a separate call from the reducer, and the session
/// token that links the two would otherwise be shared mutable state.
actor OIDCSession {

    static let shared = OIDCSession()

    static let redirectURI = "atlp://oidc-callback"

    static let callbackScheme = "atlp"

    /// allauth's default for openid_connect. Not read from the server: doing so costs a
    /// CSRF-protected round trip to learn one string. See the design note.
    static let scope = "openid profile email"

    // MARK: Step 1

    /// What the server offers.
    ///
    /// Never throws. A server with no single sign-on, one that is not paperless, and one that
    /// cannot be reached are all the same answer as far as the form is concerned: no buttons, and
    /// the password fields still work.
    func providers(url: URL) async -> [OIDCProvider] {
        do {
            let endpoint = url.appending(path: "api/auth/headless/app/v1/config")
            let (data, _) = try await ephemeral.data(from: endpoint)
            let config = try JSONDecoder().decode(HeadlessConfig.self, from: data)

            return config.data.socialaccount.providers.compactMap(\.provider)
        } catch {
            // Deliberately silent. A server with no single sign-on, one that is not paperless, and
            // one that cannot be reached are the same answer here, and the only line that could
            // distinguish them is the one that used to carry the user's hostname. ServerFormReducer
            // logs the outcome instead - from the one place that can tell discovery from the
            // preflight this method also serves.
            return []
        }
    }

    // MARK: Steps 2 to 7

    func login(provider: OIDCProvider, url: URL) async throws -> OIDCLoginResult {
        pendingSessionToken = nil

        // The preflight: a provider that is not on the server should fail here, not after the
        // browser has already opened and the user has typed a password into it.
        guard await providers(url: url).contains(where: { $0.id == provider.id }) else {
            throw OIDCError.unknownProvider(id: provider.id)
        }

        let discovery = try await discover(provider: provider)
        let pkce = PKCE()
        let state = UUID().uuidString

        let callback = try await webAuthentication.authenticate(
            authorizationURL(discovery: discovery, provider: provider, pkce: pkce, state: state),
            Self.callbackScheme
        )

        let parameters = queryParameters(of: callback)

        // Checked before the code is used for anything. A callback carrying someone else's state is
        // the attack PKCE and state exist to stop, so it fails closed.
        guard parameters["state"] == state else {
            throw OIDCError.stateMismatch
        }
        guard let code = parameters["code"] else {
            throw OIDCError.missingCode
        }

        let idToken = try await exchange(code: code, discovery: discovery, provider: provider, pkce: pkce)

        return try await redeem(idToken: idToken, provider: provider, url: url)
    }

    func confirmSecondFactor(code: String, url: URL) async throws -> String {
        guard let sessionToken = pendingSessionToken else {
            throw OIDCError.noSecondFactorPending
        }

        var request = URLRequest(url: url.appending(path: "api/auth/headless/app/v1/auth/2fa/authenticate"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(sessionToken, forHTTPHeaderField: "x-session-token")
        request.httpBody = try JSONEncoder().encode(["code": code])

        let (data, response) = try await ephemeral.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0

        guard status == 200, let token = try? JSONDecoder().decode(TokenResponse.self, from: data).meta.accessToken else {
            throw OIDCError.serverRejectedIdentity(
                status: status,
                reason: (try? JSONDecoder().decode(HeadlessFailure.self, from: data))?.summary
            )
        }

        pendingSessionToken = nil
        return token
    }

    /// Set by the redeem step when paperless asks for a second factor, and the only thing this
    /// actor remembers between calls.
    func setPendingSessionToken(_ token: String?) {
        pendingSessionToken = token
    }

    private var pendingSessionToken: String?

    /// Its own session: the flow talks to an identity provider that has nothing to do with the
    /// paperless client, and should not inherit its headers, its delegate or its cookies.
    ///
    /// Injectable so the six HTTP steps can be tested against stubbed responses. Every step but the
    /// browser is HTTP, so this is what makes the sequence testable at all.
    let ephemeral: URLSession

    init(session: URLSession = URLSession(configuration: .ephemeral)) {
        ephemeral = session
    }

    @Dependency(\.webAuthentication)
    private var webAuthentication
}
