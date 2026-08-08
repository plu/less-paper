@testable import ApiImplementation
@testable import ApiTestSupport

import ApiInterface
import CustomDump
import Dependencies
import Foundation
import Testing
import TestSupport

@Suite
struct CorrespondentsRepositoryTests {

    @Test
    func createCorrespondent_returnsTestValue() async throws {
        let output = try await repository.createCorrespondent(
            input: .testValue(),
            server: .testValue()
        )

        expectNoDifference(output, .testValue())
    }

    @Test
    func deleteCorrespondent_returnsVoid() async throws {
        try await repository.deleteCorrespondent(
            id: 1,
            server: .testValue()
        )
    }

    @Test
    func getCorrespondents_returnsTestValue() async throws {
        let output = try await repository.getCorrespondents(
            input: .testValue(),
            server: .testValue()
        )

        expectNoDifference(output, .testValue())
    }

    @Test
    func updateCorrespondent_returnsTestValue() async throws {
        let output = try await repository.updateCorrespondent(
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
        var correspondent = try await createCorrespondent()
        #expect(correspondent.documentCount == 0)
        #expect(correspondent.id > 0)
        #expect(correspondent.isInsensitive == true)
        #expect(correspondent.match == "")
        #expect(correspondent.matchingAlgorithm == .automatic)
        #expect(correspondent.name == "Test Correspondent")
        #expect(correspondent.slug == "test-correspondent")
        #expect(correspondent.userCanChange == true)

        var correspondents = try await getCorrespondents()
        #expect(correspondents.results.map(\.id) == [correspondent.id])
        #expect(correspondents.count == 1)
        #expect(correspondents.next == nil)

        let firstCorrespondent = try #require(correspondents.results.first)
        #expect(correspondent.documentCount == firstCorrespondent.documentCount)
        #expect(correspondent.id == firstCorrespondent.id)
        #expect(correspondent.isInsensitive == firstCorrespondent.isInsensitive)
        #expect(correspondent.match == firstCorrespondent.match)
        #expect(correspondent.matchingAlgorithm == firstCorrespondent.matchingAlgorithm)
        #expect(correspondent.name == firstCorrespondent.name)
        #expect(correspondent.owner == firstCorrespondent.owner)
        #expect(correspondent.slug == firstCorrespondent.slug)
        #expect(correspondent.userCanChange == firstCorrespondent.userCanChange)

        var updateCorrespondentInput = SaveCorrespondentInput(correspondent: correspondent)
        updateCorrespondentInput.name = "Updated Name"
        correspondent = try await repository.updateCorrespondent(
            id: correspondent.id,
            input: updateCorrespondentInput,
            server: .testValue()
        )
        #expect(correspondent.name == "Updated Name")

        try await deleteCorrespondent(correspondent.id)
        correspondents = try await getCorrespondents()
        #expect(correspondents.results.map(\.id) == [])
        #expect(correspondents.next == nil)
        #expect(correspondents.results == [])
    }

    init() async throws {
        try await repository.deleteAll()
    }

    private func createCorrespondent() async throws -> SaveCorrespondentOutput {
        let input = SaveCorrespondentInput(
            name: "Test Correspondent"
        )
        return try await repository.createCorrespondent(
            input: input,
            server: .testValue()
        )
    }

    private func deleteCorrespondent(_ id: Correspondent.Id) async throws -> DeleteCorrespondentOutput {
        try await repository.deleteCorrespondent(
            id: id,
            server: .testValue()
        )
    }

    private func getCorrespondents() async throws -> GetCorrespondentsOutput {
        let input = GetCorrespondentsInput()
        return try await repository.getCorrespondents(
            input: input,
            server: .testValue()
        )
    }

    @Dependency(\.correspondentsRepository)
    private var repository
}
