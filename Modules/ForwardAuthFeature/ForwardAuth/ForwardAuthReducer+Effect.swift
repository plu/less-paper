import ApiInterface
import ComposableArchitecture

extension Effect where Action == ForwardAuthReducer.Action {

    static func runForwardAuthObserver() -> Self {
        .run { send in
            @Dependency(\.forwardAuthCoordinator)
            var coordinator

            // Taking the stream also registers this reducer as the presenter. Until it runs, a
            // bounced request has nowhere to raise a login and fails rather than parking.
            for await redirect in await coordinator.redirects() {
                await send(.redirect(redirect))
            }
        }
    }

    static func runPresentConfirmation(redirect: ForwardAuthRedirect) -> Self {
        .run { send in
            @Dependency(\.forwardAuthConfirmation.present)
            var presentConfirmation

            let confirmed = await presentConfirmation(redirect.url.host() ?? redirect.url.absoluteString)

            if confirmed {
                await send(.confirmed(redirect))
            } else {
                await send(.cancelled(redirect))
            }
        }
    }

    static func runPresentSignIn(redirect: ForwardAuthRedirect) -> Self {
        .run { send in
            @Dependency(\.forwardAuthSignIn.present)
            var presentSignIn

            if await presentSignIn(redirect) {
                await send(.signInFinished(redirect))
            } else {
                await send(.signInCancelled(redirect))
            }
        }
    }

    // The sign-in landed a cookie. Every request parked against this server replays.
    static func runReleaseWaiters(redirect: ForwardAuthRedirect) -> Self {
        .run { _ in
            @Dependency(\.forwardAuthCoordinator)
            var coordinator

            await coordinator.resolve(redirect, signedIn: true)
        }
    }

    // The user backed out. The parked requests error out - which is what the user asked for by
    // dismissing. Without this distinction the sheet closes, shouldRetry replays, a new bounce
    // comes back, and the login loops.
    static func runDropWaiters(redirect: ForwardAuthRedirect) -> Self {
        .run { _ in
            @Dependency(\.forwardAuthCoordinator)
            var coordinator

            await coordinator.resolve(redirect, signedIn: false)
        }
    }
}
