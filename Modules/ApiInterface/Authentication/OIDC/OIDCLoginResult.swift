import Foundation

/// What a completed provider login yields.
///
/// A second factor is a value, not an error: the login has not failed, it is half done, and the
/// caller has a next step rather than something to report.
public enum OIDCLoginResult: Equatable, Sendable {
    case secondFactorRequired
    case token(String)
}
