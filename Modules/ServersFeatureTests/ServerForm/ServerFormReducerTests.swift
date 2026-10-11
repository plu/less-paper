@testable import ServersFeature

import ApiInterface
import Components
import ComposableArchitecture
import Foundation
import Testing
import TestSupport

@MainActor
@Suite(
    .testDependencies()
)
struct ServerFormReducerTests {

    @Test
    func test_view_cancelButtonTapped() async throws {
        var isDismissed = false
        let store = TestStore(initialState: ServerFormReducer.State(
            input: .testValue()
        )) {
            ServerFormReducer()
        } withDependencies: {
            $0.dismiss = .init { isDismissed = true }
        }

        await store.send(.view(.cancelButtonTapped))
        #expect(isDismissed == true)
    }

    @Test
    func test_view_saveButtonTapped_success() async throws {
        let events = LockIsolated<[String]>([])
        let store = TestStore(initialState: ServerFormReducer.State(
            input: .testValue()
        )) {
            ServerFormReducer()
        } withDependencies: {
            $0.storeToken.execute = { _, _, _, _ in
                events.withValue { $0.append("storeToken") }
            }
            $0.negotiateApiVersion.execute = { _ in
                events.withValue { $0.append("negotiateApiVersion") }
                return 10
            }
            $0.updateCache.execute = { _ in
                events.withValue { $0.append("updateCache") }
            }
        }

        await store.send(.view(.saveButtonTapped))
        await store.receive(\.binding, .set(\.isSaving, true)) {
            $0.isSaving = true
        }
        await store.receive(\.delegate.serverSaved, .testValue())
        await store.receive(\.binding, .set(\.isSaving, false)) {
            $0.isSaving = false
        }

        // Saving the first server selects it straight away, so its caches have
        // to be filled before it is announced as saved — otherwise the inbox
        // filter is built with no tags and shows every document.
        #expect(events.value == ["storeToken", "negotiateApiVersion", "updateCache"])
    }

    // When the probe finds a proxy-injected identity, no token is stored - the cookie is the
    // whole login - and the username the form was filled with gets replaced by whatever paperless
    // returned. That last part matters: the form's username may have been a placeholder because
    // isValid requires the field to be non-empty.
    @Test
    func test_view_saveButtonTapped_forwardAuthIdentity_storesServerWithoutToken() async throws {
        let events = LockIsolated<[String]>([])
        let store = TestStore(initialState: ServerFormReducer.State(
            input: .testValue(username: "placeholder")
        )) {
            ServerFormReducer()
        } withDependencies: {
            $0.getForwardAuthIdentity.execute = { _ in "authelia-user" }
            $0.storeServerWithoutToken.execute = { _ in
                events.withValue { $0.append("storeServerWithoutToken") }
            }
            $0.storeToken.execute = { _, _, _, _ in
                Issue.record("storeToken must not run when the proxy authenticated the identity")
            }
            $0.negotiateApiVersion.execute = { _ in
                events.withValue { $0.append("negotiateApiVersion") }
                return 10
            }
            $0.updateCache.execute = { _ in
                events.withValue { $0.append("updateCache") }
            }
        }

        await store.send(.view(.saveButtonTapped))
        await store.receive(\.binding, .set(\.isSaving, true)) {
            $0.isSaving = true
        }
        await store.receive(\.delegate.serverSaved, .testValue(username: "authelia-user"))
        await store.receive(\.binding, .set(\.isSaving, false)) {
            $0.isSaving = false
        }

        #expect(events.value == ["storeServerWithoutToken", "negotiateApiVersion", "updateCache"])
    }

    // A provider login leaves the form's username empty: no password was ever typed. Whatever
    // paperless reports for the token replaces it, or the list keeps showing "@ url".
    @Test
    func test_providerTokenReceived_savesServerWithPaperlessUsername() async throws {
        let store = TestStore(initialState: ServerFormReducer.State(
            input: .testValue(username: "")
        )) {
            ServerFormReducer()
        } withDependencies: {
            $0.storeProviderToken.execute = { _, _ in }
            $0.getCurrentUser.execute = { _ in .testValue(username: "paperless-user") }
            $0.negotiateApiVersion.execute = { _ in 10 }
            $0.updateCache.execute = { _ in }
        }

        await store.send(.providerTokenReceived("the-token"))
        await store.receive(\.delegate.serverSaved, .testValue(username: "paperless-user"))
        await store.receive(\.binding, .set(\.isSaving, false))
    }

    // Best effort: the token is already stored at this point, so a failed lookup keeps the
    // form's username rather than stranding a working login.
    @Test
    func test_providerTokenReceived_keepsFormUsernameWhenLookupFails() async throws {
        struct LookupFailed: Error {}

        let store = TestStore(initialState: ServerFormReducer.State(
            input: .testValue(username: "")
        )) {
            ServerFormReducer()
        } withDependencies: {
            $0.storeProviderToken.execute = { _, _ in }
            $0.getCurrentUser.execute = { _ in throw LookupFailed() }
            $0.negotiateApiVersion.execute = { _ in 10 }
            $0.updateCache.execute = { _ in }
        }

        await store.send(.providerTokenReceived("the-token"))
        await store.receive(\.delegate.serverSaved, .testValue(username: ""))
        await store.receive(\.binding, .set(\.isSaving, false))
    }

    @Test
    func test_isProviderLoginValid() {
        #expect(ServerFormInput.testValue().isProviderLoginValid)
    }

    @Test
    func test_isProviderLoginValid_requiresAnAlias() {
        #expect(!ServerFormInput.testValue(alias: "").isProviderLoginValid)
    }

    @Test
    func test_isProviderLoginValid_requiresAHost() {
        #expect(!ServerFormInput.testValue(url: .empty).isProviderLoginValid)
    }

    @Test
    func test_view_saveButtonTapped_cacheError() async throws {
        let toasts = LockIsolated<[Toast]>([])
        let store = TestStore(initialState: ServerFormReducer.State(
            input: .testValue()
        )) {
            ServerFormReducer()
        } withDependencies: {
            $0.storeToken.execute = { _, _, _, _ in }
            $0.updateCache.execute = { _ in throw ApiError.testValue() }
            $0.toastPresenter.present = { value in
                toasts.withValue { $0.append(value) }
            }
        }

        await store.send(.view(.saveButtonTapped))
        await store.receive(\.binding, .set(\.isSaving, true)) {
            $0.isSaving = true
        }
        await store.receive(\.error)
        await store.receive(\.binding, .set(\.isSaving, false)) {
            $0.isSaving = false
        }

        #expect(toasts.value == [.error("Something went wrong")])
    }

    @Test
    func test_view_saveButtonTapped_error() async throws {
        let toasts = LockIsolated<[Toast]>([])
        let store = TestStore(initialState: ServerFormReducer.State(
            input: .testValue()
        )) {
            ServerFormReducer()
        } withDependencies: {
            $0.storeToken.execute = { _, _, _, _ in throw ApiError.testValue() }
            $0.toastPresenter.present = { value in
                toasts.withValue { $0.append(value) }
            }
        }

        await store.send(.view(.saveButtonTapped))
        await store.receive(\.binding, .set(\.isSaving, true)) {
            $0.isSaving = true
        }
        await store.receive(\.error)
        await store.receive(\.binding, .set(\.isSaving, false)) {
            $0.isSaving = false
        }
        #expect(toasts.value == [.error("Something went wrong")])
    }

    @Test
    func test_view_saveButtonTapped_mfaCodeRequired() async throws {
        let store = TestStore(initialState: ServerFormReducer.State(
            input: .testValue()
        )) {
            ServerFormReducer()
        } withDependencies: {
            $0.storeToken.execute = { _, _, _, _ in
                throw ApiError.testValue(errors: ["MFA code is required"])
            }
        }

        await store.send(.view(.saveButtonTapped))
        await store.receive(\.binding, .set(\.isSaving, true)) {
            $0.isSaving = true
        }
        await store.receive(\.mfaCodeRequired) {
            $0.destination = .mfaForm(MfaFormReducer.State())
        }
    }

    @Test
    func test_mfaForm_cancelButtonTapped() async throws {
        var state = ServerFormReducer.State(input: .testValue())
        state.destination = .mfaForm(MfaFormReducer.State())
        state.input.code = "123456"
        state.isSaving = true

        let store = TestStore(initialState: state) {
            ServerFormReducer()
        }

        await store.send(.destination(.presented(.mfaForm(.delegate(.cancel))))) {
            $0.destination = nil
            $0.input.code = nil
            $0.isSaving = false
        }
    }

    @Test
    func test_mfaForm_mfaCodeSubmitted() async throws {
        var state = ServerFormReducer.State(input: .testValue())
        state.destination = .mfaForm(MfaFormReducer.State())

        let store = TestStore(initialState: state) {
            ServerFormReducer()
        } withDependencies: {
            $0.updateCache.execute = { _ in }
        }

        let mfaCode = "123456"
        await store.send(.destination(.presented(.mfaForm(.delegate(.mfaCode(mfaCode)))))) {
            $0.destination = nil
            $0.input.code = mfaCode
        }
        await store.receive(\.binding, .set(\.isSaving, true)) {
            $0.isSaving = true
        }
        await store.receive(\.delegate.serverSaved, .testValue())
        await store.receive(\.binding, .set(\.isSaving, false)) {
            $0.isSaving = false
        }
    }

    @Test
    func test_view_addHeaderButtonTapped() async throws {
        let store = TestStore(initialState: ServerFormReducer.State(
            input: .testValue()
        )) {
            ServerFormReducer()
        } withDependencies: {
            $0.uuid = .incrementing
        }

        await store.send(.view(.addHeaderButtonTapped)) {
            $0.input.headers = [
                HTTPHeader(id: UUID(0).uuidString, name: "", value: "")
            ]
        }
    }

    @Test
    func test_view_deleteHeaderButtonTapped() async throws {
        let header = HTTPHeader.testValue()
        let store = TestStore(initialState: ServerFormReducer.State(
            input: .testValue(headers: [header])
        )) {
            ServerFormReducer()
        }

        await store.send(.view(.deleteHeaderButtonTapped(header.id))) {
            $0.input.headers = []
        }
    }

    @Test
    func test_view_headerNameChanged() async throws {
        let header = HTTPHeader.testValue()
        let store = TestStore(initialState: ServerFormReducer.State(
            input: .testValue(headers: [header])
        )) {
            ServerFormReducer()
        }

        await store.send(.view(.headerNameChanged(header.id, "X-Custom"))) {
            $0.input.headers[id: header.id]?.name = "X-Custom"
        }
    }

    @Test
    func test_view_headerValueChanged() async throws {
        let header = HTTPHeader.testValue()
        let store = TestStore(initialState: ServerFormReducer.State(
            input: .testValue(headers: [header])
        )) {
            ServerFormReducer()
        }

        await store.send(.view(.headerValueChanged(header.id, "some-value"))) {
            $0.input.headers[id: header.id]?.value = "some-value"
        }
    }

    @Test
    func test_view_headerNameChanged_missingHeader_isNoOp() async throws {
        let store = TestStore(initialState: ServerFormReducer.State(
            input: .testValue()
        )) {
            ServerFormReducer()
        }

        await store.send(.view(.headerNameChanged("missing", "X-Custom")))
    }

    @Test
    func test_error_clearsCodeAndShowsToast() async throws {
        let toasts = LockIsolated<[Toast]>([])
        var state = ServerFormReducer.State(input: .testValue())
        state.input.code = "123456"

        let store = TestStore(initialState: state) {
            ServerFormReducer()
        } withDependencies: {
            $0.toastPresenter.present = { value in
                toasts.withValue { $0.append(value) }
            }
        }

        let error = ApiError.testValue(errors: ["Authentication failed"])
        await store.send(.error(error)) {
            $0.input.code = nil
        }
        #expect(toasts.value == [.error("Authentication failed")])
    }

    @Test
    func test_view_saveButtonTapped_unsupportedServerAbortsTheSave() async throws {
        let events = LockIsolated<[String]>([])
        let toasts = LockIsolated<[Toast]>([])
        let store = TestStore(initialState: ServerFormReducer.State(
            input: .testValue()
        )) {
            ServerFormReducer()
        } withDependencies: {
            $0.storeToken.execute = { _, _, _, _ in
                events.withValue { $0.append("storeToken") }
            }
            $0.negotiateApiVersion.execute = { _ in
                throw ApiVersionError.unsupportedServer(6)
            }
            $0.updateCache.execute = { _ in
                events.withValue { $0.append("updateCache") }
            }
            $0.toastPresenter.present = { value in
                toasts.withValue { $0.append(value) }
            }
        }

        await store.send(.view(.saveButtonTapped))
        await store.receive(\.binding, .set(\.isSaving, true)) {
            $0.isSaving = true
        }
        await store.receive(\.error)
        await store.receive(\.binding, .set(\.isSaving, false)) {
            $0.isSaving = false
        }

        #expect(events.value == ["storeToken"])

        // The toast has to name the server's own version, otherwise the user has no idea what to
        // upgrade from.
        let toast = try #require(toasts.value.first)
        guard case let .error(message) = toast else {
            Issue.record("expected an error toast, got \(toast)")
            return
        }
        #expect(message.contains("6"))
    }

    @Test
    func empty_startsWithNoHeaders() {
        withDependencies {
            $0.uuid = .incrementing
        } operation: {
            #expect(ServerFormInput.empty.headers.isEmpty)
        }
    }

    @Test
    func test_providerButtonTapped_selectsProvider() async throws {
        let provider = OIDCProvider.testValue()
        let store = TestStore(initialState: ServerFormReducer.State.testValue(
            input: .testValue(alias: ""),
            providers: [provider]
        )) {
            ServerFormReducer()
        }
        await store.send(.view(.providerButtonTapped(provider))) {
            $0.selectedProvider = provider
        }
    }

    @Test
    func test_providerButtonTapped_secondTapClearsSelection() async throws {
        let provider = OIDCProvider.testValue()
        var initial = ServerFormReducer.State.testValue(
            input: .testValue(alias: "mine"),
            providers: [provider]
        )
        initial.selectedProvider = provider
        let store = TestStore(initialState: initial) {
            ServerFormReducer()
        }
        await store.send(.view(.providerButtonTapped(provider))) {
            $0.selectedProvider = nil
        }
    }

    @Test
    func test_providerButtonTapped_switchMovesSelection() async throws {
        let first = OIDCProvider.testValue(id: "authentik")
        let second = OIDCProvider.testValue(id: "keycloak", name: "Keycloak")
        var initial = ServerFormReducer.State.testValue(
            input: .testValue(alias: "mine", password: "typed-pass", username: "typed-user"),
            providers: [first, second]
        )
        initial.selectedProvider = first
        let store = TestStore(initialState: initial) {
            ServerFormReducer()
        }
        await store.send(.view(.providerButtonTapped(second))) {
            $0.selectedProvider = second
        }
    }

    @Test
    func test_changingUrl_clearsSelection() async throws {
        let clock = TestClock()
        var initial = ServerFormReducer.State.testValue(
            input: .testValue(),
            providers: [.testValue()]
        )
        initial.selectedProvider = .testValue()
        let store = TestStore(initialState: initial) {
            ServerFormReducer()
        } withDependencies: {
            $0.continuousClock = clock
            $0.oidcClient.providers = { _ in [] }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)
        await store.send(.binding(.set(\.input.url, URL(string: "http://other.example.com")!))) {
            $0.input.url = URL(string: "http://other.example.com")!
            $0.providers = []
            $0.providersURL = URL(string: "http://other.example.com")!
            $0.selectedProvider = nil
        }
        await clock.advance(by: .milliseconds(600))
        await store.receive(\.loadProviders)
        await store.receive(\.providersLoaded)
    }

    @Test
    func test_providersLoaded_reorderedIdsKeepsSelection() async throws {
        let first = OIDCProvider.testValue(id: "authentik")
        let second = OIDCProvider.testValue(id: "keycloak", name: "Keycloak")
        var initial = ServerFormReducer.State.testValue(
            input: .testValue(),
            providers: [first, second]
        )
        initial.selectedProvider = second
        initial.lastLoggedProviderCount = 2
        let store = TestStore(initialState: initial) {
            ServerFormReducer()
        }
        await store.send(.providersLoaded([second, first])) {
            $0.providers = [second, first]
        }
    }

    @Test
    func test_isProviderLoginValid_whitespaceAliasCountsAsNonEmpty() {
        // Pins the unchanged rule: only truly empty aliases gate. A person would expect
        // whitespace blocked; changing that is a separate validation change, not this one.
        #expect(ServerFormInput.testValue(alias: " ").isProviderLoginValid)
    }

    @Test
    func test_providersLoaded_clearsSelectionForMissingId() async throws {
        var initial = ServerFormReducer.State.testValue(
            input: .testValue(),
            providers: [.testValue(id: "authentik")]
        )
        initial.selectedProvider = .testValue(id: "authentik")
        initial.lastLoggedProviderCount = 1
        let store = TestStore(initialState: initial) {
            ServerFormReducer()
        }
        await store.send(.providersLoaded([.testValue(id: "keycloak", name: "Keycloak")])) {
            $0.providers = [.testValue(id: "keycloak", name: "Keycloak")]
            $0.selectedProvider = nil
        }
    }

    @Test
    func test_saveButtonTapped_withSelection_runsProviderLogin() async throws {
        let provider = OIDCProvider.testValue()
        var initial = ServerFormReducer.State.testValue(
            input: .testValue(alias: "mine", password: "", username: ""),
            providers: [provider]
        )
        initial.selectedProvider = provider
        let store = TestStore(initialState: initial) {
            ServerFormReducer()
        } withDependencies: {
            $0.oidcClient.login = { _, _ in .token("the-token") }
            $0.storeProviderToken.execute = { _, _ in }
            $0.getCurrentUser.execute = { _ in .testValue(username: "paperless-user") }
            $0.negotiateApiVersion.execute = { _ in 10 }
            $0.updateCache.execute = { _ in }
        }
        await store.send(.view(.saveButtonTapped))
        await store.receive(\.binding, .set(\.isSaving, true)) {
            $0.isSaving = true
        }
        // The provider login effect answers through the action, not directly: runProviderLogin
        // sends .providerTokenReceived, whose own effect then saves and announces the server.
        await store.receive(\.providerTokenReceived, "the-token")
        await store.receive(\.delegate.serverSaved, .testValue(alias: "mine", username: "paperless-user"))
        await store.receive(\.binding, .set(\.isSaving, false)) {
            $0.isSaving = false
        }
    }

    @Test
    func test_providerButtonTapped_neverStartsLogin() async throws {
        let provider = OIDCProvider.testValue()
        let store = TestStore(initialState: ServerFormReducer.State.testValue(
            input: .testValue(alias: "mine"),
            providers: [provider]
        )) {
            ServerFormReducer()
        } withDependencies: {
            $0.oidcClient.login = { _, _ in
                Issue.record("selection must not start a login")
                return .token("unused")
            }
        }
        await store.send(.view(.providerButtonTapped(provider))) {
            $0.selectedProvider = provider
        }
    }

    // Editing a server that was saved without a password (OIDC, forward-auth) must store the
    // edited record while leaving the login alone: no token refresh, no keychain write.
    @Test
    func test_saveButtonTapped_passwordlessEdit_savesMetadataWithoutRefreshingToken() async throws {
        let input = ServerFormInput.testValue(alias: "renamed", password: "", username: "")
        let store = TestStore(initialState: ServerFormReducer.State(
            input: input,
            isPasswordlessEdit: true
        )) {
            ServerFormReducer()
        } withDependencies: {
            $0.storeToken.execute = { _, _, _, _ in
                Issue.record("metadata save must not refresh the password token")
            }
            $0.storeProviderToken.execute = { _, _ in
                Issue.record("metadata save must not touch the provider token")
            }
            $0.storeServerWithoutToken.execute = { _ in
                Issue.record("metadata save must not rewrite the stored server")
            }
            $0.negotiateApiVersion.execute = { _ in 10 }
            $0.updateCache.execute = { _ in }
        }

        await store.send(.view(.saveButtonTapped))
        await store.receive(\.binding, .set(\.isSaving, true)) {
            $0.isSaving = true
        }
        await store.receive(\.delegate.serverSaved, input.server)
        await store.receive(\.binding, .set(\.isSaving, false)) {
            $0.isSaving = false
        }
    }

    // The token refreshes only when a password is there to trade: clearing the password field
    // on a password-server edit keeps the existing login instead of attempting a doomed refresh.
    @Test
    func test_saveButtonTapped_clearedPassword_keepsExistingToken() async throws {
        let input = ServerFormInput.testValue(alias: "renamed", password: "")
        let store = TestStore(initialState: ServerFormReducer.State(input: input)) {
            ServerFormReducer()
        } withDependencies: {
            $0.storeToken.execute = { _, _, _, _ in
                Issue.record("an empty password has nothing to refresh the token with")
            }
            $0.negotiateApiVersion.execute = { _ in 10 }
            $0.updateCache.execute = { _ in }
        }

        await store.send(.view(.saveButtonTapped))
        await store.receive(\.binding, .set(\.isSaving, true)) {
            $0.isSaving = true
        }
        await store.receive(\.delegate.serverSaved, input.server)
        await store.receive(\.binding, .set(\.isSaving, false)) {
            $0.isSaving = false
        }
    }

    @Test
    func test_isSaveValid_passwordlessEdit() {
        var valid = ServerFormReducer.State(
            input: .testValue(alias: "renamed", password: "", username: ""),
            isPasswordlessEdit: true
        )
        #expect(valid.isSaveValid)

        valid.input.alias = ""
        #expect(!valid.isSaveValid)
    }
}
