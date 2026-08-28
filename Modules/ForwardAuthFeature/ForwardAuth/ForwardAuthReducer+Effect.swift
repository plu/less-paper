import ApiInterface
import ComposableArchitecture

extension Effect where Action == ForwardAuthReducer.Action {

    static func runForwardAuthObserver() -> Self {
        .run { send in
            @Dependency(\.forwardAuthChannel)
            var channel

            for await event in channel {
                switch event {
                case let .cancelled(redirect):
                    await send(.finish(redirect))

                case let .finish(redirect):
                    await send(.finish(redirect))

                case let .redirect(redirect):
                    await send(.redirect(redirect))
                }
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

    // The sign-in landed a cookie. Parked shouldRetry calls see .finish and replay.
    static func runReleaseWaiters(redirect: ForwardAuthRedirect) -> Self {
        .run { _ in
            @Dependency(\.forwardAuthChannel)
            var channel

            await channel.send(.finish(redirect))
        }
    }

    // The user backed out. Parked shouldRetry calls see .cancelled and return false; the
    // requests error out - which is what the user asked for by dismissing. Without this
    // distinction the popup dismisses, shouldRetry replays, a new bounce comes back, and the
    // popup loops.
    static func runDropWaiters(redirect: ForwardAuthRedirect) -> Self {
        .run { _ in
            @Dependency(\.forwardAuthChannel)
            var channel

            await channel.send(.cancelled(redirect))
        }
    }
}
