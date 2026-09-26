import ApiInterface
import Dependencies
import Foundation
import IdentifiedCollections
import SwiftSharing
import Testing
import TestSupport

@Suite(
    .testDependencies()
)
struct RemoveOfflineDocumentUseCaseTests {

    // A server per test, so the shared offline documents file cannot collide under swift-testing's
    // in-suite parallelism.
    private static func server(_ name: String) -> Server {
        .testValue(id: "remove-offline-document-use-case-tests-\(name)")
    }

    @Test
    func test_deletesThePdfAndRemovesTheRecord() async throws {
        let server = Self.server("deletes-record")
        defer { cleanUp(server) }

        let deletedId = LockIsolated<Document.Id?>(nil)

        @Shared(.offlineDocuments(server)) var offlineDocuments: IdentifiedArrayOf<OfflineDocument> = [
            .testValue(document: .testValue(id: 7))
        ]

        try await withDependencies {
            $0.offlineStore.deletePDF = { id, _ in deletedId.setValue(id) }
        } operation: {
            try await RemoveOfflineDocumentUseCase.liveValue.execute(7, server)
        }

        #expect(deletedId.value == 7)
        #expect($offlineDocuments.wrappedValue.isEmpty)
    }

    // The record goes first so that a `.refreshExisting` save cannot pass its in-lock membership
    // check after the file is already gone and write a record pointing at nothing. That ordering
    // means a failed file delete leaves the bytes behind rather than the record — an untracked file
    // wastes space, an untracked-PDF record is an offline document that cannot be opened offline.
    // The error still propagates, so the caller learns the storage total is now wrong.
    @Test
    func test_removesTheRecordEvenWhenTheDeleteFails() async {
        let server = Self.server("delete-fails")
        defer { cleanUp(server) }

        @Shared(.offlineDocuments(server)) var offlineDocuments: IdentifiedArrayOf<OfflineDocument> = [
            .testValue(document: .testValue(id: 7))
        ]

        await #expect(throws: (any Error).self) {
            try await withDependencies {
                $0.offlineStore.deletePDF = { _, _ in throw ApiError.testValue() }
            } operation: {
                try await RemoveOfflineDocumentUseCase.liveValue.execute(7, server)
            }
        }

        #expect($offlineDocuments.wrappedValue[id: 7] == nil)
    }

    // The window this ordering closes: with the file deleted first, a save already past its
    // download could still find the record present, write it, and leave the PDF it had just
    // written orphaned when the remove dropped the record a moment later.
    @Test
    func test_dropsTheRecordBeforeTouchingTheFile() async throws {
        let server = Self.server("record-before-file")
        defer { cleanUp(server) }

        let recordAtDeleteTime = LockIsolated<OfflineDocument?>(nil)

        @Shared(.offlineDocuments(server)) var offlineDocuments: IdentifiedArrayOf<OfflineDocument> = [
            .testValue(document: .testValue(id: 7))
        ]
        let shared = $offlineDocuments

        try await withDependencies {
            $0.offlineStore.deletePDF = { _, _ in
                recordAtDeleteTime.setValue(shared.wrappedValue[id: 7])
            }
        } operation: {
            try await RemoveOfflineDocumentUseCase.liveValue.execute(7, server)
        }

        #expect(recordAtDeleteTime.value == nil)
    }

    private func cleanUp(_ server: Server) {
        try? FileManager.default.removeItem(
            at: URL.applicationGroupDirectory.appending(component: "\(server.id)-offline.json")
        )
    }
}
