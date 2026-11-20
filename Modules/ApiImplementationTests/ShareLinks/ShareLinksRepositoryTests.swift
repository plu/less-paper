@testable import ApiImplementation

import ApiInterface
import CustomDump
import Dependencies
import Foundation
import Testing
import TestSupport

@Suite(
    .testDependencies()
)
struct ShareLinksRepositoryTests {

    @Test
    func createShareLink_returnsTestValue() async throws {
        let output = try await repository.createShareLink(
            input: .testValue(),
            server: .testValue()
        )

        expectNoDifference(output, .testValue())
    }

    @Test
    func deleteShareLink_returnsTestValue() async throws {
        try await repository.deleteShareLink(
            id: 1,
            server: .testValue()
        )
    }

    @Test
    func getShareLinks_returnsTestValue() async throws {
        let output = try await repository.getShareLinks(
            documentId: 1,
            server: .testValue()
        )

        expectNoDifference(output, [.testValue()])
    }

    @Test(
        .testDependencies {
            $0.authenticationProvider = .integrationTest
            $0.context = .live
        },
        .tags(.integrationTests)
    )
    func test_createGetDelete_roundTrip() async throws {
        let documentId = try await firstDocumentId()

        let created = try await repository.createShareLink(
            input: .init(
                document: documentId,
                expiration: Date.now.addingTimeInterval(24 * 60 * 60),
                fileVersion: .original
            ),
            server: .testValue()
        )

        do {
            #expect(!created.slug.isEmpty)
            #expect(created.expiration != nil)

            let fetched = try await repository.getShareLinks(
                documentId: documentId,
                server: .testValue()
            )
            #expect(fetched.contains { $0.id == created.id })
        } catch {
            try? await repository.deleteShareLink(id: created.id, server: .testValue())
            throw error
        }

        try await repository.deleteShareLink(id: created.id, server: .testValue())

        let afterDelete = try await repository.getShareLinks(
            documentId: documentId,
            server: .testValue()
        )
        #expect(!afterDelete.contains { $0.id == created.id })
    }

    @Test(
        .testDependencies {
            $0.authenticationProvider = .integrationTest
            $0.context = .live
        },
        .tags(.integrationTests)
    )
    func test_create_never_roundTrip() async throws {
        let documentId = try await firstDocumentId()

        let created = try await repository.createShareLink(
            input: .init(
                document: documentId,
                expiration: nil,
                fileVersion: .archive
            ),
            server: .testValue()
        )

        do {
            let fetched = try await repository.getShareLinks(
                documentId: documentId,
                server: .testValue()
            )
            let link = try #require(fetched.first { $0.id == created.id })
            #expect(link.expiration == nil)
        } catch {
            try? await repository.deleteShareLink(id: created.id, server: .testValue())
            throw error
        }

        try await repository.deleteShareLink(id: created.id, server: .testValue())
    }

    private func firstDocumentId() async throws -> Document.Id {
        let documents = try await documentsRepository.getDocuments(
            input: .testValue(),
            server: .testValue()
        ).results

        return try #require(documents.first).id
    }

    @Dependency(\.shareLinksRepository)
    private var repository

    @Dependency(\.documentsRepository)
    private var documentsRepository
}
