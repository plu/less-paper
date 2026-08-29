import ApiInterface
import Dependencies
import Foundation
import IdentifiedCollections
import SwiftSharing
import Testing

@Suite
struct SaveFavoriteUseCaseTests {

    // A server per test, so the shared favorites file cannot collide under swift-testing's
    // in-suite parallelism.
    private static func server(_ name: String) -> Server {
        .testValue(id: "save-favorite-use-case-tests-\(name)")
    }

    @Test
    func test_savesTheDocumentItsNotesMetadataAndPdf() async throws {
        let server = Self.server("saves-document")
        defer { cleanUp(server) }

        let document = Document.testValue(id: 7, title: "Invoice")
        let note = Note.testValue()
        let written = LockIsolated<Data?>(nil)

        @Shared(.favorites(server)) var favorites: IdentifiedArrayOf<FavoriteDocument> = []

        try await withDependencies {
            $0.getNotes.execute = { _, _ in [note] }
            $0.getDocumentMetadata.execute = { _, _ in .testValue() }
            $0.downloadDocument.execute = { _, _ in Data(repeating: 9, count: 64) }
            $0.favoritesStore.writePDF = { data, _, _ in written.setValue(data); return data.count }
            $0.date.now = Date(timeIntervalSince1970: 100)
        } operation: {
            try await SaveFavoriteUseCase.liveValue.execute(document, server, .add)
        }

        #expect(written.value?.count == 64)
        #expect($favorites.wrappedValue[id: 7]?.document.title == "Invoice")
        #expect($favorites.wrappedValue[id: 7]?.notes == [note])
        #expect($favorites.wrappedValue[id: 7]?.pdfByteCount == 64)
        #expect($favorites.wrappedValue[id: 7]?.isUnavailable == false)
    }

    // A failed download must leave nothing behind: a record without its PDF is a favorite that
    // cannot be read offline, which is the one thing it exists to do.
    @Test
    func test_writesNoRecordWhenTheDownloadFails() async {
        let server = Self.server("download-fails")
        defer { cleanUp(server) }

        @Shared(.favorites(server)) var favorites: IdentifiedArrayOf<FavoriteDocument> = []

        await #expect(throws: (any Error).self) {
            try await withDependencies {
                $0.getNotes.execute = { _, _ in [] }
                $0.getDocumentMetadata.execute = { _, _ in .testValue() }
                $0.downloadDocument.execute = { _, _ in throw ApiError.testValue() }
            } operation: {
                try await SaveFavoriteUseCase.liveValue.execute(.testValue(id: 7), server, .add)
            }
        }

        #expect($favorites.wrappedValue.isEmpty)
    }

    // A refresh must not put back a favorite the user removed while its fetch was in flight, and
    // losing that race must not strand the PDF the save had already written.
    @Test
    func test_aRefreshSaveDoesNotResurrectAFavoriteRemovedMidFlight() async throws {
        let server = Self.server("removed-mid-save")
        defer { cleanUp(server) }

        let deleted = LockIsolated<Document.Id?>(nil)

        @Shared(.favorites(server)) var favorites: IdentifiedArrayOf<FavoriteDocument> = [
            .testValue(document: .testValue(id: 7))
        ]
        let shared = $favorites

        try await withDependencies {
            $0.getNotes.execute = { _, _ in [] }
            $0.getDocumentMetadata.execute = { _, _ in .testValue() }
            $0.downloadDocument.execute = { _, _ in
                shared.withLock { $0.remove(id: 7) }
                return Data(repeating: 9, count: 64)
            }
            $0.favoritesStore.writePDF = { data, _, _ in data.count }
            $0.favoritesStore.deletePDF = { id, _ in deleted.setValue(id) }
            $0.date.now = Date(timeIntervalSince1970: 100)
        } operation: {
            try await SaveFavoriteUseCase.liveValue.execute(
                .testValue(id: 7),
                server,
                .refreshExisting
            )
        }

        #expect($favorites.wrappedValue[id: 7] == nil)
        #expect(deleted.value == 7)
    }

    private func cleanUp(_ server: Server) {
        try? FileManager.default.removeItem(
            at: URL.applicationGroupDirectory.appending(component: "\(server.id)-favorites.json")
        )
    }
}
