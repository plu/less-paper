public enum ForwardAuthEvent: Equatable, Sendable {
    case finish(ForwardAuthRedirect)
    case redirect(ForwardAuthRedirect)
}
