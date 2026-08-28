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

        // Drives the login sheet through the parent view's .sheet(item:) binding. Set only after
        // the confirmation popup is confirmed.
        public var sheet: ForwardAuthRedirect?

        public init(
            redirect: ForwardAuthRedirect? = nil,
            sheet: ForwardAuthRedirect? = nil
        ) {
            self.redirect = redirect
            self.sheet = sheet
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
                // A user who dismisses the popup is a user who has decided not to sign in. The
                // parked request has to be released - .finish is the only signal shouldRetry
                // waits for, and this sends it so shouldRetry returns false rather than hangs.
                state.redirect = nil
                return .runReleaseWaiters(redirect: redirect)

            case let .confirmed(redirect):
                // Present the sheet. The web view's completion sends .signInFinished; a
                // user-dismissed sheet reaches .signInCancelled through the binding's
                // .onDismiss.
                state.sheet = redirect
                return .none

            case let .finish(redirect):
                guard state.redirect == redirect else {
                    return .none
                }
                state.redirect = nil
                state.sheet = nil
                return .none

            case let .redirect(redirect):
                guard state.redirect == nil else {
                    return .none
                }
                state.redirect = redirect
                return .runPresentConfirmation(redirect: redirect)

            case let .signInCancelled(redirect):
                state.sheet = nil
                state.redirect = nil
                return .runReleaseWaiters(redirect: redirect)

            case let .signInFinished(redirect):
                state.sheet = nil
                state.redirect = nil
                return .runReleaseWaiters(redirect: redirect)
            }
        }
    }

    public init() {}
}
