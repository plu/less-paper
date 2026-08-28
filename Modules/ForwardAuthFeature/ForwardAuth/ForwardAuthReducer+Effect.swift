import ApiInterface
import ComposableArchitecture

extension Effect where Action == ForwardAuthReducer.Action {

    static func runForwardAuthObserver() -> Self {
        .run { send in
            @Dependency(\.forwardAuthChannel)
            var channel

            for await event in channel {
                switch event {
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

    static func runReleaseWaiters(redirect: ForwardAuthRedirect) -> Self {
        .run { _ in
            @Dependency(\.forwardAuthChannel)
            var channel

            await channel.send(.finish(redirect))
        }
    }
}
