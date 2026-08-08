@testable import ApiImplementation
@testable import ApiTestSupport

import ApiInterface
import CustomDump
import Dependencies
import Foundation
import Testing
import TestSupport

@Suite
struct GroupsRepositoryTests {

    @Test
    func createGroup_returnsTestValue() async throws {
        let output = try await repository.createGroup(
            input: .testValue(),
            server: .testValue()
        )

        expectNoDifference(output, .testValue())
    }

    @Test
    func deleteGroup_returnsVoid() async throws {
        try await repository.deleteGroup(
            id: 1,
            server: .testValue()
        )
    }

    @Test
    func getGroups_returnsTestValue() async throws {
        let output = try await repository.getGroups(
            input: .testValue(),
            server: .testValue()
        )

        expectNoDifference(output, .testValue())
    }

    @Test
    func updateGroup_returnsTestValue() async throws {
        let output = try await repository.updateGroup(
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
        var group = try await createGroup()
        #expect(group.name == "Admins")
        #expect(group.permissions.sorted() == Permission.allCases.sorted())

        var groups = try await getGroups()
        #expect(groups.results.map(\.id).contains(group.id))
        #expect(groups.count == 1)
        #expect(groups.next == nil)
        #expect(groups.results.contains(group))

        let updateGroupInput = SaveGroupInput(
            name: "Updated Admins",
            permissions: [.addDocument]
        )
        group = try await repository.updateGroup(
            id: group.id,
            input: updateGroupInput,
            server: .testValue()
        )
        #expect(group.name == "Updated Admins")
        #expect(group.permissions == [.addDocument])

        try await deleteGroup(group.id)
        groups = try await getGroups()
        #expect(groups.results.map(\.id) == [])
        #expect(groups.next == nil)
        #expect(groups.next == nil)
        #expect(groups.results == [])
    }

    init() async throws {
        try await repository.deleteAll()
    }

    private func createGroup() async throws -> SaveGroupOutput {
        let input = SaveGroupInput(
            name: "Admins",
            permissions: Permission.allCases
        )
        return try await repository.createGroup(
            input: input,
            server: .testValue()
        )
    }

    private func deleteGroup(_ id: Group.Id) async throws -> DeleteGroupOutput {
        try await repository.deleteGroup(
            id: id,
            server: .testValue()
        )
    }

    private func getGroups() async throws -> GetGroupsOutput {
        let input = GetGroupsInput()
        return try await repository.getGroups(
            input: input,
            server: .testValue()
        )
    }

    @Dependency(\.groupsRepository)
    private var repository
}
