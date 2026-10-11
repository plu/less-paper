import Foundation

/// The ways a provider login fails, named so each one can be reported as something to do about it.
///
/// `localizedDescription` on the underlying error is almost never useful here - "The operation
/// couldn't be completed" tells a user nothing they can act on, and the actionable part is usually a
/// piece of server configuration only an administrator can change.
public enum OIDCError: Error, Equatable, Sendable {

    /// The provider sent back a state that was not the one we sent. Either something went wrong, or
    /// someone is trying something; either way the code is not exchanged.
    case stateMismatch

    /// The callback arrived without an authorization code.
    case missingCode

    /// The provider the user picked is not one the server offers.
    case unknownProvider(id: String)

    /// The provider has no OpenID configuration URL, so there is nothing to discover.
    case missingConfigurationURL(provider: String)

    /// The redirect URI is not registered with the identity provider. Names the URI, because the
    /// fix is for someone to add exactly this string, and a generic failure sends them hunting.
    case redirectURINotRegistered(uri: String)

    /// The user closed the browser without finishing. Not a failure to report.
    case cancelled

    /// The provider rejected the code exchange.
    case tokenExchangeFailed(reason: String)

    /// The provider rejected the code exchange because the client authenticates with a secret.
    /// A native app has nowhere to keep one, so it always exchanges without it: this client has
    /// to be turned into a public PKCE client on the provider side.
    case confidentialClient(provider: String)

    /// paperless accepted the identity but staged a signup instead of logging in, because the
    /// identity matches no paperless user. A second factor screen can never satisfy this stage,
    /// so it is reported rather than asked for.
    case accountNotLinked(provider: String)

    /// paperless rejected the identity, or answered in a way that was not understood. Carries what
    /// the server said, because allauth names the field it objected to and that is the whole answer.
    case serverRejectedIdentity(status: Int, reason: String?)

    /// A second factor was expected but there is no login waiting for one.
    case noSecondFactorPending
}

extension OIDCError: LocalizedError {

    public var errorDescription: String? {
        switch self {
        case let .accountNotLinked(provider):
            String(localized: .oidcAccountNotLinked(provider))
        case let .confidentialClient(provider):
            String(localized: .oidcConfidentialClient(provider))
        default:
            nil
        }
    }
}
