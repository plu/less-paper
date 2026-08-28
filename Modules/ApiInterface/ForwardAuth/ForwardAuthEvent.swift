public enum ForwardAuthEvent: Equatable, Sendable {
    // A login the user backed out of. shouldRetry returns false and the parked request errors
    // out - which is what the user asked for by dismissing.
    case cancelled(ForwardAuthRedirect)

    // The sign-in completed and the cookie is now in app-group storage. shouldRetry returns
    // true and the parked request replays with the cookie in place.
    case finish(ForwardAuthRedirect)

    case redirect(ForwardAuthRedirect)
}
