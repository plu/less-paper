@testable import ApiImplementation
@testable import ApiTestSupport

import ApiInterface
import CustomDump
import Dependencies
import Foundation
import Testing
import TestSupport

@Suite
struct TagsRepositoryTests {

    @Test
    func createTag_returnsTestValue() async throws {
        let output = try await repository.createTag(
            input: .testValue(),
            server: .testValue()
        )

        expectNoDifference(output, .testValue())
    }

    @Test
    func deleteTag_returnsVoid() async throws {
        try await repository.deleteTag(
            id: 1,
            server: .testValue()
        )
    }

    @Test
    func getTags_returnsTestValue() async throws {
        let output = try await repository.getTags(
            input: .testValue(),
            server: .testValue()
        )

        expectNoDifference(output, .testValue())
    }

    @Test
    func updateTag_returnsTestValue() async throws {
        let output = try await repository.updateTag(
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
        var tag = try await createTag()
        #expect(tag.color == "#ff0000")
        #expect(tag.documentCount == 0)
        #expect(tag.id > 0)
        #expect(tag.isInboxTag == true)
        #expect(tag.isInsensitive == true)
        #expect(tag.match == "")
        #expect(tag.matchingAlgorithm == .automatic)
        #expect(tag.name == "Some Inbox")
        #expect(tag.slug == "some-inbox")
        #expect(tag.textColor == "#000000")
        #expect(tag.userCanChange == true)

        var tags = try await getTags()
        #expect(tags.results.map(\.id) == [tag.id])
        #expect(tags.count == 1)
        #expect(tags.next == nil)

        let firstTag = try #require(tags.results.first)
        #expect(tag.color == firstTag.color)
        #expect(tag.documentCount == firstTag.documentCount)
        #expect(tag.id == firstTag.id)
        #expect(tag.isInboxTag == firstTag.isInboxTag)
        #expect(tag.isInsensitive == firstTag.isInsensitive)
        #expect(tag.match == firstTag.match)
        #expect(tag.matchingAlgorithm == firstTag.matchingAlgorithm)
        #expect(tag.name == firstTag.name)
        #expect(tag.owner == firstTag.owner)
        #expect(tag.slug == firstTag.slug)
        #expect(tag.textColor == firstTag.textColor)
        #expect(tag.userCanChange == firstTag.userCanChange)

        var updateTagInput = SaveTagInput(tag: tag)
        updateTagInput.name = "Updated Name"
        tag = try await repository.updateTag(
            id: tag.id,
            input: updateTagInput,
            server: .testValue()
        )
        #expect(tag.name == "Updated Name")

        try await deleteTag(tag.id)
        tags = try await getTags()
        #expect(tags.results.map(\.id) == [])
        #expect(tags.next == nil)
        #expect(tags.results == [])
    }

    init() async throws {
        try await repository.deleteAll()
    }

    private func createTag() async throws -> SaveTagOutput {
        let input = SaveTagInput(
            color: "#ff0000",
            isInboxTag: true,
            name: "Some Inbox"
        )
        return try await repository.createTag(
            input: input,
            server: .testValue()
        )
    }

    private func deleteTag(_ id: ApiInterface.Tag.Id) async throws -> DeleteTagOutput {
        try await repository.deleteTag(
            id: id,
            server: .testValue()
        )
    }

    private func getTags() async throws -> GetTagsOutput {
        let input = GetTagsInput()
        return try await repository.getTags(
            input: input,
            server: .testValue()
        )
    }

    @Dependency(\.tagsRepository)
    private var repository
}
