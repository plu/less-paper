import ApiInterface
import Components
import ComposableArchitecture

@Reducer
public struct ForwardAuthReducer: Sendable {

    @CasePathable
    public enum Action {

        case bootstrap

        case cancelled(ForwardAuthRedirect)

        case confirmed(ForwardAuthRedirect)

        case finish(ForwardAuthRedirect)

        case redirect(ForwardAuthRedirect)
    }

    @ObservableState
    public struct State: Equatable {

        public var redirect: ForwardAuthRedirect?

        public init(redirect: ForwardAuthRedirect? = nil) {
            self.redirect = redirect
        }
    }

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .bootstrap:
                return .runForwardAuthObserver()

            case let .cancelled(redirect):
                // A user who dismisses the popup is a user who has decided not to sign in. The
                // parked request has to be released - .finish is the only signal shouldRetry
                // waits for, and this sends it so shouldRetry returns false rather than hangs.
                state.redirect = nil
                return .runReleaseWaiters(redirect: redirect)

            case let .confirmed(redirect):
                // The web view will send .finish on the channel when the cookie lands, so the
                // reducer's state clears in the .finish branch. Task 10 replaces this with the
                // sheet presentation.
                return .runReleaseWaiters(redirect: redirect)

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
                return .runPresentConfirmation(redirect: redirect)
            }
        }
    }

    public init() {}
}
