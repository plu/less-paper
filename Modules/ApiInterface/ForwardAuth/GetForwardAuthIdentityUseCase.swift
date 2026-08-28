import Dependencies
import DependenciesMacros

@DependencyClient
public struct GetForwardAuthIdentityUseCase: Sendable {

    // `nil` when the proxy only gates the request; the caller then runs the ordinary token login.
    // A non-nil username means paperless authenticated the proxy-injected identity, and no
    // token needs to be stored.
    public var execute: @Sendable (
        _ server: Server
    ) async throws -> String?
}

extension GetForwardAuthIdentityUseCase: TestDependencyKey {

    // nil is the "gate-only or not-a-proxy" answer, which is what every existing test that never
    // heard of forward auth wants. A test that cares about the remote-user path stubs execute
    // to return a username explicitly.
    public static let testValue = Self(
        execute: { _ in nil }
    )
}

public extension DependencyValues {

    var getForwardAuthIdentity: GetForwardAuthIdentityUseCase {
        get { self[GetForwardAuthIdentityUseCase.self] }
        set { self[GetForwardAuthIdentityUseCase.self] = newValue }
    }
}
