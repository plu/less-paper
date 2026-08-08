@testable import ApiImplementation
@testable import ApiTestSupport

import ApiInterface
import CustomDump
import Dependencies
import Foundation
import Testing
import TestSupport

@Suite
struct PermissionsRepositoryTests {

    @Test
    func getPermissions_returnsTestValue() async throws {
        let output = try await permissionsRepository.getPermissions(
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
        let groups = try await [
            groupsRepository.createGroup(
                input: .testValue(
                    name: "Admins"
                ),
                server: .testValue()
            ),
            groupsRepository.createGroup(
                input: .testValue(
                    name: "Users"
                ),
                server: .testValue()
            )
        ]

        let users = try await [
            usersRepository.createUser(
                input: .testValue(
                    email: "jane@doe.com",
                    username: "jane"
                ),
                server: .testValue()
            ),
            usersRepository.createUser(
                input: .testValue(
                    email: "john@doe.com",
                    username: "john"
                ),
                server: .testValue()
            )
        ]

        let tag = try await tagsRepository.createTag(
            input: .testValue(
                name: "Tag Permissions",
                setPermissions: .init(
                    change: .init(
                        groups: [groups.first?.id].compactMap(\.self),
                        users: [users.first?.id].compactMap(\.self)
                    ),
                    view: .init(
                        groups: groups.map(\.id),
                        users: users.map(\.id)
                    )
                )
            ),
            server: .testValue()
        )

        let permissions = try await permissionsRepository.getPermissions(
            input: .init(type: .tag(id: tag.id)),
            server: .testValue()
        )

        expectNoDifference(permissions, .init(
            owner: tag.owner,
            permissions: .init(
                change: .init(
                    groups: [groups.first?.id].compactMap(\.self),
                    users: [users.first?.id].compactMap(\.self)
                ),
                view: .init(
                    groups: groups.map(\.id),
                    users: users.map(\.id)
                )
            )
        ))
    }

    init() async throws {
        try await groupsRepository.deleteAll()
        try await tagsRepository.deleteAll()
        try await usersRepository.deleteAll()
    }

    @Dependency(\.groupsRepository)
    private var groupsRepository

    @Dependency(\.permissionsRepository)
    private var permissionsRepository

    @Dependency(\.tagsRepository)
    private var tagsRepository

    @Dependency(\.usersRepository)
    private var usersRepository
}
