@testable import ApiImplementation

import ApiInterface
import Dependencies
import Foundation
import Testing
import TestSupport

@Suite(
    .dependencies()
)
struct NotesRepositoryTests {

    @Test(
        .dependencies {
            $0.authenticationProvider = .integrationTest
            $0.context = .live
        },
        .tags(.integrationTests)
    )
    func test_createGetDelete_roundTrip() async throws {
        let documentId = try await firstDocumentId()
        let text = "Note from NotesRepositoryTests \(UUID().uuidString)"

        let afterCreate = try await repository.createNote(
            documentId: documentId,
            input: .init(note: text),
            server: .testValue()
        )
        let created = try #require(afterCreate.first { $0.note == text })

        // Every verb answers with the document's complete list, which is what lets the reducer
        // replace its state outright instead of reconciling.
        let fetched = try await repository.getNotes(
            documentId: documentId,
            server: .testValue()
        )
        #expect(fetched.contains(created))
        #expect(!created.user.username.isEmpty)

        let afterDelete = try await repository.deleteNote(
            documentId: documentId,
            noteId: created.id,
            server: .testValue()
        )
        #expect(!afterDelete.contains { $0.id == created.id })
    }

    private func firstDocumentId() async throws -> Document.Id {
        let documents = try await documentsRepository.getDocuments(
            input: .testValue(),
            server: .testValue()
        ).results

        return try #require(documents.first).id
    }

    @Dependency(\.notesRepository)
    private var repository

    @Dependency(\.documentsRepository)
    private var documentsRepository
}
