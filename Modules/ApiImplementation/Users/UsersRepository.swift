import ApiInterface
import Dependencies
import DependenciesMacros
import Foundation
import Get

@DependencyClient
struct UsersRepository: Sendable {

    var createUser: @Sendable (
        _ input: SaveUserInput,
        _ server: Server
    ) async throws -> SaveUserOutput

    var deleteUser: @Sendable (
        _ id: User.Id,
        _ server: Server
    ) async throws -> DeleteUserOutput

    var getUser: @Sendable (
        _ input: GetUserInput,
        _ server: Server
    ) async throws -> GetUserOutput

    var getUsers: @Sendable (
        _ input: GetUsersInput,
        _ server: Server
    ) async throws -> GetUsersOutput

    var updateUser: @Sendable (
        _ id: User.Id,
        _ input: SaveUserInput,
        _ server: Server
    ) async throws -> SaveUserOutput
}

extension UsersRepository: TestDependencyKey {

    static let previewValue = Self(
        createUser: { _, _ in .testValue() },
        deleteUser: { _, _ in },
        getUser: { _, _ in .testValue() },
        getUsers: { _, _ in .testValue() },
        updateUser: { _, _, _ in .testValue() }
    )

    static let testValue = Self(
        createUser: { _, _ in .testValue() },
        deleteUser: { _, _ in },
        getUser: { _, _ in .testValue() },
        getUsers: { _, _ in .testValue() },
        updateUser: { _, _, _ in .testValue() }
    )
}

extension DependencyValues {

    var usersRepository: UsersRepository {
        get { self[UsersRepository.self] }
        set { self[UsersRepository.self] = newValue }
    }
}

extension UsersRepository: DependencyKey {
    static let liveValue = Self(
        createUser: createUser(input:server:),
        deleteUser: deleteUser(id:server:),
        getUser: getUser(input:server:),
        getUsers: getUsers(input:server:),
        updateUser: updateUser(id:input:server:)
    )
}

private extension UsersRepository {

    static func createUser(
        input: SaveUserInput,
        server: Server
    ) async throws -> SaveUserOutput {
        try await APIClient
            .client(server: server)
            .send(.init(
                path: "/api/users/",
                method: .post,
                body: input
            ))
            .value
    }

    static func deleteUser(
        id: User.Id,
        server: Server
    ) async throws {
        try await APIClient
            .client(server: server)
            .send(.init(
                path: "/api/users/\(id)/",
                method: .delete
            ))
            .value
    }

    static func getUser(
        input: GetUserInput,
        server: Server
    ) async throws -> GetUserOutput {
        try await APIClient
            .client(server: server)
            .send(.init(
                path: "/api/users/\(input.id)/",
                method: .get
            ))
            .value
    }

    static func getUsers(
        input: GetUsersInput,
        server: Server
    ) async throws -> GetUsersOutput {
        try await APIClient
            .client(server: server)
            .send(.init(input: input))
            .value
    }

    static func updateUser(
        id: User.Id,
        input: SaveUserInput,
        server: Server
    ) async throws -> SaveUserOutput {
        try await APIClient
            .client(server: server)
            .send(.init(
                path: "/api/users/\(id)/",
                method: .patch,
                body: input
            ))
            .value
    }
}

private extension Request where Response == GetUsersOutput {

    init(input: GetUsersInput) {
        if let url = input.url {
            self.init(
                url: url,
                method: .get
            )
            return
        }
        self.init(
            path: "/api/users/",
            method: .get
        )
    }
}
