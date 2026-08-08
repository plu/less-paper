import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
public struct AuthenticationProvider: Sendable {

    public var getToken: @Sendable (
        _ server: Server
    ) async throws -> String
}

extension AuthenticationProvider: TestDependencyKey {
    public static let testValue = Self(
        getToken: { _ in "c0ff33" }
    )
}

public extension DependencyValues {

    var authenticationProvider: AuthenticationProvider {
        get { self[AuthenticationProvider.self] }
        set { self[AuthenticationProvider.self] = newValue }
    }
}
