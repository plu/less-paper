import ApiInterface
import Dependencies
import DependenciesMacros
import Foundation
import Get

@DependencyClient
struct AuthenticationRepository: Sendable {

    var getToken: @Sendable (
        _ input: GetTokenInput,
        _ server: Server
    ) async throws -> GetTokenOutput
}

extension AuthenticationRepository: TestDependencyKey {
    static let testValue = Self(
        getToken: { _, _ in .testValue() }
    )
}

extension DependencyValues {

    var authenticationRepository: AuthenticationRepository {
        get { self[AuthenticationRepository.self] }
        set { self[AuthenticationRepository.self] = newValue }
    }
}

extension AuthenticationRepository: DependencyKey {
    static let liveValue = Self(
        getToken: getToken(input:server:)
    )
}

private extension AuthenticationRepository {

    static func getToken(
        input: GetTokenInput,
        server: Server
    ) async throws -> GetTokenOutput {
        try await APIClient
            .client(server: server)
            .send(.init(
                path: "/api/token/",
                method: .post,
                body: input
            ))
            .value
    }
}
