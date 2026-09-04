import ApiInterface
import Components
import ComposableArchitecture
import Foundation
import Logging
import SwiftUI

@Reducer
public struct ServerFormReducer: Sendable {

    public enum Action: BindableAction, ViewAction {
        case binding(BindingAction<State>)
        case delegate(Delegate)
        case destination(PresentationAction<Destination.Action>)
        case error(Error)
        case mfaCodeRequired
        case loadProviders
        case providerTokenReceived(String)
        case providersLoaded([OIDCProvider])
        case view(View)

        @CasePathable
        public enum Delegate {
            case serverSaved(Server)
        }

        public enum View {
            case addHeaderButtonTapped
            case cancelButtonTapped
            case closeButtonTapped
            case providerButtonTapped(OIDCProvider)
            case deleteHeaderButtonTapped(HTTPHeader.ID)
            case urlCommitted
            case headerNameChanged(HTTPHeader.ID, String)
            case headerValueChanged(HTTPHeader.ID, String)
            case saveButtonTapped
        }
    }

    @Reducer
    public enum Destination {
        case mfaForm(MfaFormReducer)
    }

    @ObservableState
    public struct State: Equatable {

        @Presents
        var destination: Destination.State?

        var input: ServerFormInput

        var isSaving = false

        /// Set while a provider login is waiting for its second factor, so the shared MFA sheet
        /// knows which login to finish - the password flow re-runs the save with a code, this one
        /// confirms against the pending provider session.
        var isAwaitingProviderSecondFactor = false

        /// What the server offers. Empty is the ordinary case and means the form looks as it always
        /// has.
        var providers: [OIDCProvider] = []

        /// The address `providers` was read from, so a change can be noticed without depending on
        /// which keypath a binding action happens to carry.
        var providersURL: URL?

        // Distinct from `providers`, which is cleared to [] before every load: comparing against
        // that would suppress the first "none" - the one worth having - while still logging later
        // ones. nil means nothing has been logged for this form yet.
        var lastLoggedProviderCount: Int?

        var section = ServerFormSection.form

        public init(
            destination: Destination.State? = nil,
            input: ServerFormInput = .empty
        ) {
            self.destination = destination
            self.input = input
            // Seeded with the address the form opened on, so only a change asks the server. Left
            // nil, the first binding of any kind - a username keystroke - would look like a new
            // address and send a request nobody asked for.
            providersURL = input.url
        }
    }

    public var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case let .destination(.presented(.mfaForm(.delegate(delegateAction)))):
                switch delegateAction {
                case .cancel:
                    state.destination = nil
                    state.input.code = nil
                    state.isAwaitingProviderSecondFactor = false
                    state.isSaving = false
                    return .none
                case let .mfaCode(code):
                    state.destination = nil
                    if state.isAwaitingProviderSecondFactor {
                        state.isAwaitingProviderSecondFactor = false
                        return .runConfirmProviderSecondFactor(code: code, input: state.input)
                    }
                    state.input.code = code
                    return .runSaveServer(input: state.input)
                }
            case let .error(error):
                state.input.code = nil
                return .toast(error)
            case .mfaCodeRequired:
                state.destination = .mfaForm(MfaFormReducer.State())
                return .none
            case .loadProviders:
                return .runLoadProviders(input: state.input)
            case let .providerTokenReceived(token):
                return .runSaveProviderToken(input: state.input, token: token)
            case let .providersLoaded(providers):
                state.providers = providers
                if state.lastLoggedProviderCount != providers.count {
                    state.lastLoggedProviderCount = providers.count
                    log.info(Self.discoveryMessage(count: providers.count), category: .server)
                }
                return .none
            case let .view(viewAction):
                switch viewAction {
                case .addHeaderButtonTapped:
                    @Dependency(\.uuid)
                    var uuid

                    state.input.headers.append(HTTPHeader(id: uuid().uuidString, name: "", value: ""))
                    return .none
                case .cancelButtonTapped, .closeButtonTapped:
                    return .run { _ in
                        await dismiss()
                    }
                case let .deleteHeaderButtonTapped(id):
                    state.input.headers.remove(id: id)
                    return .none
                case let .headerNameChanged(id, name):
                    state.input.headers[id: id]?.name = name
                    return .none
                case let .headerValueChanged(id, value):
                    state.input.headers[id: id]?.value = value
                    return .none
                case let .providerButtonTapped(provider):
                    return .runProviderLogin(input: state.input, provider: provider)
                case .urlCommitted:
                    return .runLoadProviders(input: state.input)
                case .saveButtonTapped:
                    return .runSaveServer(input: state.input)
                }
            case .binding:
                // Compared by value rather than matched on \.input.url: ServerFormInput is a plain
                // struct inside an @ObservableState State, so a chained binding does not
                // necessarily carry the nested keypath, and matching on it silently never fires.
                guard state.input.url != state.providersURL else {
                    return .none
                }
                state.providers = []
                state.providersURL = state.input.url
                return .runLoadProvidersDebounced()
            case .delegate, .destination:
                return .none
            }
        }
        .ifLet(\.$destination, action: \.destination)
    }

    public init() {}

    static func discoveryMessage(count: Int) -> String {
        switch count {
        case 0: "OIDC discovery: none"
        case 1: "OIDC discovery: 1 provider"
        default: "OIDC discovery: \(count) providers"
        }
    }

    @Dependency(\.dismiss)
    private var dismiss

    @Dependency(\.log)
    private var log
}

extension ServerFormReducer.Destination.State: Equatable {}
