import ApiInterface
import ComposableArchitecture

@Reducer
public struct ForwardAuthReducer: Sendable {

    @CasePathable
    public enum Action {

        case bootstrap

        case cancelled(ForwardAuthRedirect)

        case confirmed(ForwardAuthRedirect)

        case redirect(ForwardAuthRedirect)

        // The sheet reports its outcome back so the reducer can clear state and release parked
        // requests either way. dismissal by the user is a decision, not just a lifecycle event.
        case signInFinished(ForwardAuthRedirect)

        case signInCancelled(ForwardAuthRedirect)
    }

    public struct State: Equatable {

        // Set when a bounce is received. Cleared when the whole flow finishes: either sign-in
        // succeeded, or the user dismissed something along the way. Not observed by any view -
        // both the popup and the sheet are presented, not declared - so it is only the guard that
        // keeps a second login off the screen.
        public var redirect: ForwardAuthRedirect?

        public init(
            redirect: ForwardAuthRedirect? = nil
        ) {
            self.redirect = redirect
        }
    }

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
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

            case let .redirect(redirect):
                guard state.redirect == nil else {
                    // A second server bouncing while this login is up. Its requests are told no
                    // rather than left waiting for a sheet that cannot present over the first
                    // one; they raise a login of their own the next time they are tried.
                    return .runDropWaiters(redirect: redirect)
                }
                state.redirect = redirect
                // The host is named before a browser opens, not after: this is the one moment
                // credentials get typed, and a full-screen login that appears by itself cannot
                // say where it came from until it has already loaded.
                return .runPresentConfirmation(redirect: redirect)

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
