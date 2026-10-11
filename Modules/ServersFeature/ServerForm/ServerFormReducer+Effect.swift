import ApiInterface
import ComposableArchitecture

extension Effect where Action == ServerFormReducer.Action {

    static func runSaveServer(
        input: ServerFormInput
    ) -> Self {
        @Dependency(\.getForwardAuthIdentity.execute)
        var getForwardAuthIdentity

        @Dependency(\.negotiateApiVersion.execute)
        var negotiateApiVersion

        @Dependency(\.storeServerWithoutToken.execute)
        var storeServerWithoutToken

        @Dependency(\.storeToken.execute)
        var storeToken

        @Dependency(\.updateCache.execute)
        var updateCache

        return .run { send in
            await send(.binding(.set(\.isSaving, true)))

            // Probe first: if the cookie the user picked up from the forward-auth login (or one
            // that survived from a previous session) makes an unauthenticated /api/ui_settings/
            // succeed, the proxy is injecting a trusted identity and no token is needed.
            if let username = try await getForwardAuthIdentity(input.server) {
                let server = input.server.with(username: username)
                try await storeServerWithoutToken(server)
                _ = try await negotiateApiVersion(server)
                try await updateCache(server)
                await send(.delegate(.serverSaved(server)), animation: .default)
                await send(.binding(.set(\.isSaving, false)))
                return
            }

            try await storeToken(input.code, input.password, input.server, input.username)
            _ = try await negotiateApiVersion(input.server)
            try await updateCache(input.server)
            await send(.delegate(.serverSaved(input.server)), animation: .default)
            await send(.binding(.set(\.isSaving, false)))
        } catch: { error, send in
            if error.isMfaCodeRequiredError {
                await send(.mfaCodeRequired)
                return
            }
            await send(.error(error))
            await send(.binding(.set(\.isSaving, false)))
        }
        .cancellable(id: CancelID.saveServer)
    }

    static func runSaveServerMetadata(
        input: ServerFormInput
    ) -> Self {
        @Dependency(\.negotiateApiVersion.execute)
        var negotiateApiVersion

        @Dependency(\.updateCache.execute)
        var updateCache

        return .run { send in
            await send(.binding(.set(\.isSaving, true)))

            // No password, no refresh: the stored login stays exactly as it is, so there is
            // nothing to probe for and nothing to write to the keychain. Version and cache
            // still re-run against the edited record, or the list shows a stale server.
            _ = try await negotiateApiVersion(input.server)
            try await updateCache(input.server)
            await send(.delegate(.serverSaved(input.server)), animation: .default)
            await send(.binding(.set(\.isSaving, false)))
        } catch: { error, send in
            await send(.error(error))
            await send(.binding(.set(\.isSaving, false)))
        }
        .cancellable(id: CancelID.saveServer)
    }
}

extension Effect where Action == ServerFormReducer.Action {

    /// Waits for the address to settle before asking. Typing a URL produces one change per
    /// keystroke, and every prefix of a hostname is a request to somewhere.
    static func runLoadProvidersDebounced() -> Self {
        @Dependency(\.continuousClock)
        var clock

        return .run { send in
            try await clock.sleep(for: .milliseconds(600))
            await send(.loadProviders)
        }
        .cancellable(id: CancelID.loadProviders, cancelInFlight: true)
    }

    /// Asks the server what it offers, and never fails. A server with no single sign-on, one that
    /// cannot be reached, and one that is not paperless are the same answer here: no buttons.
    static func runLoadProviders(input: ServerFormInput) -> Self {
        @Dependency(\.oidcClient)
        var oidcClient

        return .run { send in
            await send(.providersLoaded(try await oidcClient.providers(input.server.url)))
        } catch: { _, send in
            await send(.providersLoaded([]))
        }
        .cancellable(id: CancelID.loadProviders, cancelInFlight: true)
    }

    static func runProviderLogin(input: ServerFormInput, provider: OIDCProvider) -> Self {
        @Dependency(\.oidcClient)
        var oidcClient

        return .run { send in
            await send(.binding(.set(\.isSaving, true)))

            switch try await oidcClient.login(provider, input.server.url) {
            case let .token(token):
                await send(.providerTokenReceived(token))
            case .secondFactorRequired:
                await send(.binding(.set(\.isAwaitingProviderSecondFactor, true)))
                await send(.mfaCodeRequired)
            }
        } catch: { error, send in
            // Closing the browser is a decision, not something to report back as a failure.
            if case OIDCError.cancelled = error {
                await send(.binding(.set(\.isSaving, false)))
                return
            }
            await send(.error(error))
            await send(.binding(.set(\.isSaving, false)))
        }
        .cancellable(id: CancelID.providerLogin, cancelInFlight: true)
    }

    static func runConfirmProviderSecondFactor(code: String, input: ServerFormInput) -> Self {
        @Dependency(\.oidcClient)
        var oidcClient

        return .run { send in
            let token = try await oidcClient.confirmSecondFactor(code, input.server.url)
            await send(.providerTokenReceived(token))
        } catch: { error, send in
            await send(.error(error))
            await send(.binding(.set(\.isSaving, false)))
        }
    }

    /// The token is already in hand, so this only stores it and does what saving always does -
    /// negotiate the API version and warm the cache - which is what makes a provider login
    /// indistinguishable from a password one everywhere downstream.
    static func runSaveProviderToken(input: ServerFormInput, token: String) -> Self {
        @Dependency(\.getCurrentUser.execute)
        var getCurrentUser

        @Dependency(\.getForwardAuthIdentity.execute)
        var getForwardAuthIdentity

        @Dependency(\.negotiateApiVersion.execute)
        var negotiateApiVersion

        @Dependency(\.storeProviderToken.execute)
        var storeProviderToken

        @Dependency(\.storeServerWithoutToken.execute)
        var storeServerWithoutToken

        @Dependency(\.updateCache.execute)
        var updateCache

        return .run { send in
            // Probe first even on the provider path. A user could be behind a proxy that
            // *also* offers OIDC through the same identity provider - remote-user mode wins if
            // paperless says so.
            if let username = try await getForwardAuthIdentity(input.server) {
                let server = input.server.with(username: username)
                try await storeServerWithoutToken(server)
                _ = try await negotiateApiVersion(server)
                try await updateCache(server)
                await send(.delegate(.serverSaved(server)), animation: .default)
                await send(.binding(.set(\.isSaving, false)))
                return
            }

            try await storeProviderToken(input.server, token)
            // A provider login fills no username: the form fields are meaningless when the
            // provider authenticates the human. Paperless knows who the token belongs to - the
            // same authority the forward-auth identity above carries - so whatever it returns
            // replaces the empty field rather than showing "@ url" wherever a username is
            // expected. Best effort: the login already succeeded, and losing a working token
            // over display metadata would strand it.
            let server: Server
            if let username = try? await getCurrentUser(input.server).username {
                server = input.server.with(username: username)
            } else {
                server = input.server
            }
            _ = try await negotiateApiVersion(server)
            try await updateCache(server)
            await send(.delegate(.serverSaved(server)), animation: .default)
            await send(.binding(.set(\.isSaving, false)))
        } catch: { error, send in
            await send(.error(error))
            await send(.binding(.set(\.isSaving, false)))
        }
        .cancellable(id: CancelID.saveServer)
    }
}

private enum CancelID {
    case loadProviders
    case providerLogin
    case saveServer
}
