@testable import ApiImplementation

import ApiInterface
import Dependencies
import Foundation

public struct TestUser: Sendable {

    public let configuration: UITestConfiguration

    public let id: User.Id

    public let namespace: String

    public let password: String

    public static func create() async throws -> Self {
        let namespace = "uit-\(UUID().uuidString.prefix(8).lowercased())"
        let password = "T3st!\(UUID().uuidString.prefix(12))"

        let user = try await withAdminDependencies {
            @Dependency(\.usersRepository)
            var usersRepository

            return try await usersRepository.createUser(
                input: SaveUserInput(
                    email: "\(namespace)@example.com",
                    password: password,
                    userPermissions: Permission.allCases,
                    username: namespace
                ),
                server: .testValue()
            )
        }

        let token = try await withAdminDependencies {
            @Dependency(\.authenticationRepository)
            var authenticationRepository

            return try await authenticationRepository.getToken(
                input: GetTokenInput(
                    code: nil,
                    password: password,
                    username: namespace
                ),
                server: .testValue()
            ).token
        }

        return Self(
            configuration: UITestConfiguration(
                seed: .init(
                    password: password,
                    server: .testValue(username: namespace),
                    token: token
                )
            ),
            id: user.id,
            namespace: namespace,
            password: password
        )
    }

    public func delete() async throws {
        try await withAdminDependencies {
            @Dependency(\.usersRepository)
            var usersRepository

            _ = try await usersRepository.deleteUser(
                id: id,
                server: .testValue()
            )
        }
    }

    // A crashed or cancelled run leaves its user behind and the container outlives the run, so
    // without this they accumulate across CI runs.
    public static func sweepOrphans() async throws {
        try await withAdminDependencies {
            @Dependency(\.usersRepository)
            var usersRepository

            let users = try await usersRepository.getUsers(
                input: .testValue(),
                server: .testValue()
            ).results

            for user in users where user.username.hasPrefix("uit-") {
                _ = try? await usersRepository.deleteUser(
                    id: user.id,
                    server: .testValue()
                )
            }
        }
    }
}

@discardableResult
public func withAdminDependencies<R>(
    isolation: isolated (any Actor)? = #isolation,
    operation: () async throws -> R
) async rethrows -> R {
    try await withDependencies {
        $0.authenticationProvider = .integrationTest
        $0.context = .live
    } operation: {
        try await operation()
    }
}
