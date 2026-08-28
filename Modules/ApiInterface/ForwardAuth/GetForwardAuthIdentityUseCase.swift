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

    public static let testValue = Self()
}

public extension DependencyValues {

    var getForwardAuthIdentity: GetForwardAuthIdentityUseCase {
        get { self[GetForwardAuthIdentityUseCase.self] }
        set { self[GetForwardAuthIdentityUseCase.self] = newValue }
    }
}
