@testable import ApiImplementation
@testable import ApiTestSupport

import ApiInterface
import CustomDump
import Dependencies
import Foundation
import Testing
import TestSupport

@Suite
struct UsersRepositoryTests {

    @Test
    func createUser_returnsTestValue() async throws {
        let output = try await repository.createUser(
            input: .testValue(),
            server: .testValue()
        )

        expectNoDifference(output, .testValue())
    }

    @Test
    func deleteUser_returnsVoid() async throws {
        try await repository.deleteUser(
            id: 1,
            server: .testValue()
        )
    }

    @Test
    func getUser_returnsTestValue() async throws {
        let output = try await repository.getUser(
            input: .testValue(),
            server: .testValue()
        )

        expectNoDifference(output, .testValue())
    }

    @Test
    func getUsers_returnsTestValue() async throws {
        let output = try await repository.getUsers(
            input: .testValue(),
            server: .testValue()
        )

        expectNoDifference(output, .testValue())
    }

    @Test
    func updateUser_returnsTestValue() async throws {
        let output = try await repository.updateUser(
            id: 1,
            input: .testValue(),
            server: .testValue()
        )

        expectNoDifference(output, .testValue())
    }

    @Test(
        .dependencies {
            $0.authenticationProvider = .integrationTest
            $0.context = .live
        },
        .tags(.integrationTests)
    )
    func crud() async throws {
        var user = try await createUser()
        #expect(user.email == "jane@doe.com")
        #expect(user.username == "jdoe")

        var users = try await getUsers()
        #expect(users.results.map(\.id).contains(user.id))
        #expect(users.count == 2)
        #expect(users.next == nil)
        #expect(users.results.contains(user))

        let sameUser = try await repository.getUser(input: .init(id: user.id), server: .testValue())
        expectNoDifference(sameUser, user)

        var updateUserInput = SaveUserInput(user: user)
        updateUserInput.firstName = "JANE"
        updateUserInput.userPermissions = Permission.allCases
        user = try await repository.updateUser(
            id: user.id,
            input: updateUserInput,
            server: .testValue()
        )
        #expect(user.firstName == "JANE")
        #expect(user.userPermissions.sorted() == Permission.allCases.sorted())

        try await deleteUser(user.id)
        users = try await getUsers()
        #expect(!users.results.map(\.id).contains(user.id))
        #expect(users.next == nil)
        #expect(users.count == 1)
        #expect(users.next == nil)
        #expect(!users.results.contains(user))
    }

    init() async throws {
        try await repository.deleteAll()
    }

    private func createUser() async throws -> SaveUserOutput {
        let input = SaveUserInput(
            email: "jane@doe.com",
            password: "T0PS3CR3T!!123",
            username: "jdoe"
        )
        return try await repository.createUser(
            input: input,
            server: .testValue()
        )
    }

    private func deleteUser(_ id: User.Id) async throws -> DeleteUserOutput {
        try await repository.deleteUser(
            id: id,
            server: .testValue()
        )
    }

    private func getUsers() async throws -> GetUsersOutput {
        let input = GetUsersInput()
        return try await repository.getUsers(
            input: input,
            server: .testValue()
        )
    }

    @Dependency(\.usersRepository)
    private var repository
}
