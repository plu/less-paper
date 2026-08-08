import ApiInterface
import Dependencies
import DependenciesMacros
import Foundation
import Get

@DependencyClient
struct TagsRepository: Sendable {

    var createTag: @Sendable (
        _ input: SaveTagInput,
        _ server: Server
    ) async throws -> SaveTagOutput

    var deleteTag: @Sendable (
        _ id: Tag.Id,
        _ server: Server
    ) async throws -> DeleteTagOutput

    var getTags: @Sendable (
        _ input: GetTagsInput,
        _ server: Server
    ) async throws -> GetTagsOutput

    var updateTag: @Sendable (
        _ id: Tag.Id,
        _ input: SaveTagInput,
        _ server: Server
    ) async throws -> SaveTagOutput
}

extension TagsRepository: TestDependencyKey {

    static let previewValue = Self(
        createTag: { _, _ in .testValue() },
        deleteTag: { _, _ in },
        getTags: { _, _ in .testValue(results: .previewValue) },
        updateTag: { _, _, _ in .testValue() }
    )

    static let testValue = Self(
        createTag: { _, _ in .testValue() },
        deleteTag: { _, _ in },
        getTags: { _, _ in .testValue() },
        updateTag: { _, _, _ in .testValue() }
    )
}

extension DependencyValues {

    var tagsRepository: TagsRepository {
        get { self[TagsRepository.self] }
        set { self[TagsRepository.self] = newValue }
    }
}

extension TagsRepository: DependencyKey {
    static let liveValue = Self(
        createTag: createTag(input:server:),
        deleteTag: deleteTag(id:server:),
        getTags: getTags(input:server:),
        updateTag: updateTag(id:input:server:)
    )
}

private extension TagsRepository {

    static func createTag(
        input: SaveTagInput,
        server: Server
    ) async throws -> SaveTagOutput {
        try await APIClient
            .client(server: server)
            .send(.init(
                path: "/api/tags/",
                method: .post,
                body: input
            ))
            .value
    }

    static func deleteTag(
        id: Tag.Id,
        server: Server
    ) async throws {
        try await APIClient
            .client(server: server)
            .send(.init(
                path: "/api/tags/\(id)/",
                method: .delete
            ))
            .value
    }

    static func getTags(
        input: GetTagsInput,
        server: Server
    ) async throws -> GetTagsOutput {
        try await APIClient
            .client(server: server)
            .send(.init(input: input))
            .value
    }

    static func updateTag(
        id: Tag.Id,
        input: SaveTagInput,
        server: Server
    ) async throws -> SaveTagOutput {
        try await APIClient
            .client(server: server)
            .send(.init(
                path: "/api/tags/\(id)/",
                method: .patch,
                body: input
            ))
            .value
    }
}

private extension Request where Response == GetTagsOutput {

    init(input: GetTagsInput) {
        if let url = input.url {
            self.init(
                url: url,
                method: .get
            )
            return
        }
        self.init(
            path: "/api/tags/",
            method: .get
        )
    }
}
