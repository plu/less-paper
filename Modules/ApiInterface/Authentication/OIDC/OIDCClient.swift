import Dependencies
import DependenciesMacros
import Foundation

/// Signing in through a provider the server has configured.
///
/// Three calls rather than one, because the flow has two points where it stops and waits for a
/// person: the browser, and the second factor. Modelling those as separate calls keeps the waiting
/// in the reducer, where it can be cancelled, rather than inside a single opaque await.
@DependencyClient
public struct OIDCClient: Sendable {

    /// What the server offers. An empty list is the ordinary answer for a server with no single
    /// sign-on configured, and for one that is not paperless at all.
    public var providers: @Sendable (_ url: URL) async throws -> [OIDCProvider] = { _ in [] }

    public var login: @Sendable (
        _ provider: OIDCProvider,
        _ url: URL
    ) async throws -> OIDCLoginResult

    public var confirmSecondFactor: @Sendable (
        _ code: String,
        _ url: URL
    ) async throws -> String
}

extension OIDCClient: TestDependencyKey {

    public static let previewValue = Self(
        providers: { _ in [.testValue()] },
        login: { _, _ in .token("c0ff33") },
        confirmSecondFactor: { _, _ in "c0ff33" }
    )

    public static let testValue = Self()
}

public extension DependencyValues {

    var oidcClient: OIDCClient {
        get { self[OIDCClient.self] }
        set { self[OIDCClient.self] = newValue }
    }
}
