import ApiInterface
import Foundation

extension OIDCSession {

    // MARK: Step 2

    /// The provider's own advertisement of where its endpoints are. Discovered rather than
    /// configured, because only the provider knows.
    func discover(provider: OIDCProvider) async throws -> Discovery {
        let (data, response) = try await ephemeral.data(from: provider.configurationURL)

        guard (response as? HTTPURLResponse)?.statusCode == 200,
              let discovery = try? JSONDecoder().decode(Discovery.self, from: data)
        else {
            throw OIDCError.missingConfigurationURL(provider: provider.name)
        }

        return discovery
    }

    // MARK: Step 3

    func authorizationURL(
        discovery: Discovery,
        provider: OIDCProvider,
        pkce: PKCE,
        state: String
    ) -> URL {
        var components = URLComponents(url: discovery.authorizationEndpoint, resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "client_id", value: provider.clientId),
            URLQueryItem(name: "code_challenge", value: pkce.challenge),
            // S256 rather than plain: plain sends the verifier itself, which proves nothing to
            // anyone who can already see the request.
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "redirect_uri", value: OIDCSession.redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: OIDCSession.scope),
            URLQueryItem(name: "state", value: state),
        ]

        return components?.url ?? discovery.authorizationEndpoint
    }

    func queryParameters(of url: URL) -> [String: String] {
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        return items.reduce(into: [:]) { result, item in
            result[item.name] = item.value
        }
    }

    // MARK: Step 6

    /// No client secret. A native app cannot keep one, so the verifier is what proves this is the
    /// same client that asked for the code.
    func exchange(
        code: String,
        discovery: Discovery,
        provider: OIDCProvider,
        pkce: PKCE
    ) async throws -> String {
        var request = URLRequest(url: discovery.tokenEndpoint)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = formBody([
            "client_id": provider.clientId,
            "code": code,
            "code_verifier": pkce.verifier,
            "grant_type": "authorization_code",
            "redirect_uri": OIDCSession.redirectURI,
        ])

        let (data, response) = try await ephemeral.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0

        guard status == 200 else {
            let failure = try? JSONDecoder().decode(OAuthFailure.self, from: data)
            // A provider that has not been told about our redirect URI says so here, and it is the
            // likeliest thing to be wrong, so it is named rather than passed through as noise.
            if failure?.error == "invalid_grant" || failure?.error == "invalid_request",
               failure?.errorDescription?.lowercased().contains("redirect") == true {
                throw OIDCError.redirectURINotRegistered(uri: OIDCSession.redirectURI)
            }
            throw OIDCError.tokenExchangeFailed(reason: failure?.errorDescription ?? failure?.error ?? "status \(status)")
        }

        guard let token = try? JSONDecoder().decode(ProviderToken.self, from: data).idToken else {
            // No id_token means an OAuth2 flow ran instead of an OIDC one, which is what happens
            // when the openid scope is missing. There is nothing to hand paperless.
            throw OIDCError.tokenExchangeFailed(reason: "the provider returned no id_token")
        }

        return token
    }

    // MARK: Step 7

    /// Trades the provider's identity for a paperless API token - the same kind of token the
    /// username and password flow produces, and the only thing the rest of the app knows about.
    func redeem(idToken: String, provider: OIDCProvider, url: URL) async throws -> OIDCLoginResult {
        var request = URLRequest(url: url.appending(path: "api/auth/headless/app/v1/auth/provider/token"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(ProviderTokenRequest(
            process: "login",
            provider: provider.id,
            token: .init(clientId: provider.clientId, idToken: idToken)
        ))

        let (data, response) = try await ephemeral.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        let decoded = try? JSONDecoder().decode(TokenResponse.self, from: data)

        if let token = decoded?.meta.accessToken, status == 200 {
            return .token(token)
        }

        // 401 with a session token is not a rejection: it is paperless saying the identity was
        // accepted and a second factor is still owed.
        if let sessionToken = decoded?.meta.sessionToken {
            setPendingSessionToken(sessionToken)
            return .secondFactorRequired
        }

        throw OIDCError.serverRejectedIdentity(
            status: status,
            reason: (try? JSONDecoder().decode(HeadlessFailure.self, from: data))?.summary
        )
    }

    private func formBody(_ parameters: [String: String]) -> Data {
        var components = URLComponents()
        components.queryItems = parameters
            .sorted { $0.key < $1.key }
            .map { URLQueryItem(name: $0.key, value: $0.value) }

        return Data((components.percentEncodedQuery ?? "").utf8)
    }
}
