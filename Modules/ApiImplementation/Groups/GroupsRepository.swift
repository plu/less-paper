import ApiInterface
import Dependencies
import DependenciesMacros
import Foundation
import Get

@DependencyClient
struct GroupsRepository: Sendable {

    var createGroup: @Sendable (
        _ input: SaveGroupInput,
        _ server: Server
    ) async throws -> SaveGroupOutput

    var deleteGroup: @Sendable (
        _ id: Group.Id,
        _ server: Server
    ) async throws -> DeleteGroupOutput

    var getGroups: @Sendable (
        _ input: GetGroupsInput,
        _ server: Server
    ) async throws -> GetGroupsOutput

    var updateGroup: @Sendable (
        _ id: Group.Id,
        _ input: SaveGroupInput,
        _ server: Server
    ) async throws -> SaveGroupOutput
}

extension GroupsRepository: TestDependencyKey {

    static let previewValue = Self(
        createGroup: { _, _ in .testValue() },
        deleteGroup: { _, _ in },
        getGroups: { _, _ in .testValue() },
        updateGroup: { _, _, _ in .testValue() }
    )

    static let testValue = Self(
        createGroup: { _, _ in .testValue() },
        deleteGroup: { _, _ in },
        getGroups: { _, _ in .testValue() },
        updateGroup: { _, _, _ in .testValue() }
    )
}

extension DependencyValues {

    var groupsRepository: GroupsRepository {
        get { self[GroupsRepository.self] }
        set { self[GroupsRepository.self] = newValue }
    }
}

extension GroupsRepository: DependencyKey {
    static let liveValue = Self(
        createGroup: createGroup(input:server:),
        deleteGroup: deleteGroup(id:server:),
        getGroups: getGroups(input:server:),
        updateGroup: updateGroup(id:input:server:)
    )
}

private extension GroupsRepository {

    static func createGroup(
        input: SaveGroupInput,
        server: Server
    ) async throws -> SaveGroupOutput {
        try await APIClient
            .client(server: server)
            .send(.init(
                path: "/api/groups/",
                method: .post,
                body: input
            ))
            .value
    }

    static func deleteGroup(
        id: Group.Id,
        server: Server
    ) async throws {
        try await APIClient
            .client(server: server)
            .send(.init(
                path: "/api/groups/\(id)/",
                method: .delete
            ))
            .value
    }

    static func getGroups(
        input: GetGroupsInput,
        server: Server
    ) async throws -> GetGroupsOutput {
        try await APIClient
            .client(server: server)
            .send(.init(input: input))
            .value
    }

    static func updateGroup(
        id: Group.Id,
        input: SaveGroupInput,
        server: Server
    ) async throws -> SaveGroupOutput {
        try await APIClient
            .client(server: server)
            .send(.init(
                path: "/api/groups/\(id)/",
                method: .patch,
                body: input
            ))
            .value
    }
}

private extension Request where Response == GetGroupsOutput {

    init(input: GetGroupsInput) {
        if let url = input.url {
            self.init(
                url: url,
                method: .get
            )
            return
        }
        self.init(
            path: "/api/groups/",
            method: .get
        )
    }
}
