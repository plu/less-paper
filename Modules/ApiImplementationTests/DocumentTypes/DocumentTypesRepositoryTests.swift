@testable import ApiImplementation
@testable import ApiTestSupport

import ApiInterface
import CustomDump
import Dependencies
import Foundation
import Testing
import TestSupport

@Suite
struct DocumentTypesRepositoryTests {

    @Test
    func createDocumentType_returnsTestValue() async throws {
        let output = try await repository.createDocumentType(
            input: .testValue(),
            server: .testValue()
        )

        expectNoDifference(output, .testValue())
    }

    @Test
    func deleteDocumentType_returnsVoid() async throws {
        try await repository.deleteDocumentType(
            id: 1,
            server: .testValue()
        )
    }

    @Test
    func getDocumentTypes_returnsTestValue() async throws {
        let output = try await repository.getDocumentTypes(
            input: .testValue(),
            server: .testValue()
        )

        expectNoDifference(output, .testValue())
    }

    @Test
    func updateDocumentType_returnsTestValue() async throws {
        let output = try await repository.updateDocumentType(
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
        var documentType = try await createDocumentType()
        #expect(documentType.documentCount == 0)
        #expect(documentType.id > 0)
        #expect(documentType.isInsensitive == true)
        #expect(documentType.match == "")
        #expect(documentType.matchingAlgorithm == .automatic)
        #expect(documentType.name == "Test DocumentType")
        #expect(documentType.slug == "test-documenttype")
        #expect(documentType.userCanChange == true)

        var documenttypes = try await getDocumentTypes()
        #expect(documenttypes.results.map(\.id) == [documentType.id])
        #expect(documenttypes.count == 1)
        #expect(documenttypes.next == nil)

        let firstDocumentType = try #require(documenttypes.results.first)
        #expect(documentType.documentCount == firstDocumentType.documentCount)
        #expect(documentType.id == firstDocumentType.id)
        #expect(documentType.isInsensitive == firstDocumentType.isInsensitive)
        #expect(documentType.match == firstDocumentType.match)
        #expect(documentType.matchingAlgorithm == firstDocumentType.matchingAlgorithm)
        #expect(documentType.name == firstDocumentType.name)
        #expect(documentType.owner == firstDocumentType.owner)
        #expect(documentType.slug == firstDocumentType.slug)
        #expect(documentType.userCanChange == firstDocumentType.userCanChange)

        var updateDocumentTypeInput = SaveDocumentTypeInput(documentType: documentType)
        updateDocumentTypeInput.name = "Updated Name"
        documentType = try await repository.updateDocumentType(
            id: documentType.id,
            input: updateDocumentTypeInput,
            server: .testValue()
        )
        #expect(documentType.name == "Updated Name")

        try await deleteDocumentType(documentType.id)
        documenttypes = try await getDocumentTypes()
        #expect(documenttypes.results.map(\.id) == [])
        #expect(documenttypes.next == nil)
        #expect(documenttypes.results == [])
    }

    init() async throws {
        try await repository.deleteAll()
    }

    private func createDocumentType() async throws -> SaveDocumentTypeOutput {
        let input = SaveDocumentTypeInput(
            name: "Test DocumentType"
        )
        return try await repository.createDocumentType(
            input: input,
            server: .testValue()
        )
    }

    private func deleteDocumentType(_ id: DocumentType.Id) async throws -> DeleteDocumentTypeOutput {
        try await repository.deleteDocumentType(
            id: id,
            server: .testValue()
        )
    }

    private func getDocumentTypes() async throws -> GetDocumentTypesOutput {
        let input = GetDocumentTypesInput()
        return try await repository.getDocumentTypes(
            input: input,
            server: .testValue()
        )
    }

    @Dependency(\.documentTypesRepository)
    private var repository
}
