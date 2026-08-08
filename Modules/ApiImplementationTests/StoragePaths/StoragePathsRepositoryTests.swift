@testable import ApiImplementation
@testable import ApiTestSupport

import ApiInterface
import CustomDump
import Dependencies
import Foundation
import Testing
import TestSupport

@Suite
struct StoragePathsRepositoryTests {

    @Test
    func createStoragePath_returnsTestValue() async throws {
        let output = try await repository.createStoragePath(
            input: .testValue(),
            server: .testValue()
        )

        expectNoDifference(output, .testValue())
    }

    @Test
    func deleteStoragePath_returnsVoid() async throws {
        try await repository.deleteStoragePath(
            id: 1,
            server: .testValue()
        )
    }

    @Test
    func getStoragePaths_returnsTestValue() async throws {
        let output = try await repository.getStoragePaths(
            input: .testValue(),
            server: .testValue()
        )

        expectNoDifference(output, .testValue())
    }

    @Test
    func updateStoragePath_returnsTestValue() async throws {
        let output = try await repository.updateStoragePath(
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
        var storagePath = try await createStoragePath()
        #expect(storagePath.documentCount == 0)
        #expect(storagePath.id > 0)
        #expect(storagePath.isInsensitive == true)
        #expect(storagePath.match == "")
        #expect(storagePath.matchingAlgorithm == .automatic)
        #expect(storagePath.name == "Test StoragePath")
        #expect(storagePath.slug == "test-storagepath")
        #expect(storagePath.userCanChange == true)

        var storagePaths = try await getStoragePaths()
        #expect(storagePaths.results.map(\.id) == [storagePath.id])
        #expect(storagePaths.count == 1)
        #expect(storagePaths.next == nil)

        let firstStoragePath = try #require(storagePaths.results.first)
        #expect(storagePath.documentCount == firstStoragePath.documentCount)
        #expect(storagePath.id == firstStoragePath.id)
        #expect(storagePath.isInsensitive == firstStoragePath.isInsensitive)
        #expect(storagePath.match == firstStoragePath.match)
        #expect(storagePath.matchingAlgorithm == firstStoragePath.matchingAlgorithm)
        #expect(storagePath.name == firstStoragePath.name)
        #expect(storagePath.owner == firstStoragePath.owner)
        #expect(storagePath.slug == firstStoragePath.slug)
        #expect(storagePath.userCanChange == firstStoragePath.userCanChange)

        var updateStoragePathInput = SaveStoragePathInput(storagePath: storagePath)
        updateStoragePathInput.name = "Updated Name"
        storagePath = try await repository.updateStoragePath(
            id: storagePath.id,
            input: updateStoragePathInput,
            server: .testValue()
        )
        #expect(storagePath.name == "Updated Name")

        try await deleteStoragePath(storagePath.id)
        storagePaths = try await getStoragePaths()
        #expect(storagePaths.results.map(\.id) == [])
        #expect(storagePaths.next == nil)
        #expect(storagePaths.results == [])
    }

    init() async throws {
        try await repository.deleteAll()
    }

    private func createStoragePath() async throws -> SaveStoragePathOutput {
        let input = SaveStoragePathInput(
            name: "Test StoragePath",
            path: "/home/paperless/test-storagepath"
        )
        return try await repository.createStoragePath(
            input: input,
            server: .testValue()
        )
    }

    private func deleteStoragePath(_ id: StoragePath.Id) async throws -> DeleteStoragePathOutput {
        try await repository.deleteStoragePath(
            id: id,
            server: .testValue()
        )
    }

    private func getStoragePaths() async throws -> GetStoragePathsOutput {
        let input = GetStoragePathsInput()
        return try await repository.getStoragePaths(
            input: input,
            server: .testValue()
        )
    }

    @Dependency(\.storagePathsRepository)
    private var repository
}
