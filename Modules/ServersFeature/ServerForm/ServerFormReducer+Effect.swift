import ApiInterface
import ComposableArchitecture

extension Effect where Action == ServerFormReducer.Action {

    static func runSaveServer(
        input: ServerFormInput
    ) -> Self {
        @Dependency(\.negotiateApiVersion.execute)
        var negotiateApiVersion

        @Dependency(\.storeToken.execute)
        var storeToken

        @Dependency(\.updateCache.execute)
        var updateCache

        return .run { send in
            await send(.binding(.set(\.isSaving, true)))
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
        @Dependency(\.negotiateApiVersion.execute)
        var negotiateApiVersion

        @Dependency(\.storeProviderToken.execute)
        var storeProviderToken

        @Dependency(\.updateCache.execute)
        var updateCache

        return .run { send in
            try await storeProviderToken(input.server, token)
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

private enum CancelID {
    case loadProviders
    case providerLogin
    case saveServer
}
