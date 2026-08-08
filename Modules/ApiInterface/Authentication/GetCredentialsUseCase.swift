import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
public struct GetCredentialsUseCase: Sendable {
    public var execute: @Sendable (
        _ server: Server
    ) async throws -> Credentials
}

extension GetCredentialsUseCase: TestDependencyKey {
    public static let previewValue = Self(
        execute: { _ in .testValue() }
    )

    public static let testValue = Self(
        execute: { _ in .testValue() }
    )
}

public extension DependencyValues {
    var getCredentials: GetCredentialsUseCase {
        get { self[GetCredentialsUseCase.self] }
        set { self[GetCredentialsUseCase.self] = newValue }
    }
}
