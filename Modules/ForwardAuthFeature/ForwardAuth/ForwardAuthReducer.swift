import ApiInterface
import Components
import ComposableArchitecture

@Reducer
public struct ForwardAuthReducer: Sendable {

    @CasePathable
    public enum Action: BindableAction {

        case binding(BindingAction<State>)

        case bootstrap

        case cancelled(ForwardAuthRedirect)

        case confirmed(ForwardAuthRedirect)

        case finish(ForwardAuthRedirect)

        case redirect(ForwardAuthRedirect)

        // The sheet reports its outcome back so the reducer can clear state and release parked
        // requests either way. dismissal by the user is a decision, not just a lifecycle event.
        case signInFinished(ForwardAuthRedirect)

        case signInCancelled(ForwardAuthRedirect)
    }

    @ObservableState
    public struct State: Equatable {

        // Set when a bounce is received. Cleared when the whole flow finishes: either sign-in
        // succeeded, or the user dismissed something along the way.
        public var redirect: ForwardAuthRedirect?

        public init(
            redirect: ForwardAuthRedirect? = nil
        ) {
            self.redirect = redirect
        }
    }

    public var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .bootstrap:
                return .runForwardAuthObserver()

            case let .cancelled(redirect):
                // A user who dismisses the popup is a user who has decided not to sign in. Drop
                // the parked requests rather than releasing them - releasing means shouldRetry
                // returns true and the request replays, gets bounced again, and the popup comes
                // right back.
                state.redirect = nil
                return .runDropWaiters(redirect: redirect)

            case let .confirmed(redirect):
                // Presented by ForwardAuthSignInPresenter rather than by a .sheet on AppView: the
                // bounce arrives while the server form sheet is up, and SwiftUI queues a second
                // sheet from the same host until the first one is dismissed.
                return .runPresentSignIn(redirect: redirect)

            case let .finish(redirect):
                guard state.redirect == redirect else {
                    return .none
                }
                state.redirect = nil
                return .none

            case let .redirect(redirect):
                guard state.redirect == nil else {
                    return .none
                }
                state.redirect = redirect
                // Skip the confirmation popup for now: it presents through SwiftMessages on its
                // own window, and dismissing it as the sheet tries to present is the current
                // suspect for the sheet never appearing. The sheet's own title bar names the
                // host, so a first-pass user still sees where they are being sent.
                state.sheet = redirect
                return .none

            case let .signInCancelled(redirect):
                // Same reasoning as .cancelled above: a dismissed sheet drops the waiters, it
                // does not release them.
                state.redirect = nil
                return .runDropWaiters(redirect: redirect)

            case let .signInFinished(redirect):
                state.redirect = nil
                return .runReleaseWaiters(redirect: redirect)
            }
        }
    }

    public init() {}
}
