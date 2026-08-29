import ApiInterface
import Dependencies
import Foundation
import IdentifiedCollections
import SwiftSharing
import Testing

@Suite
struct RemoveFavoriteUseCaseTests {

    // A server per test, so the shared favorites file cannot collide under swift-testing's
    // in-suite parallelism.
    private static func server(_ name: String) -> Server {
        .testValue(id: "remove-favorite-use-case-tests-\(name)")
    }

    @Test
    func test_deletesThePdfAndRemovesTheRecord() async throws {
        let server = Self.server("deletes-record")
        defer { cleanUp(server) }

        let deletedId = LockIsolated<Document.Id?>(nil)

        @Shared(.favorites(server)) var favorites: IdentifiedArrayOf<FavoriteDocument> = [
            .testValue(document: .testValue(id: 7))
        ]

        try await withDependencies {
            $0.favoritesStore.deletePDF = { id, _ in deletedId.setValue(id) }
        } operation: {
            try await RemoveFavoriteUseCase.liveValue.execute(7, server)
        }

        #expect(deletedId.value == 7)
        #expect($favorites.wrappedValue.isEmpty)
    }

    // A failed delete must not remove the record: an entry whose PDF is still on disk but no
    // longer tracked would leak until the whole per-server directory is wiped.
    @Test
    func test_keepsTheRecordWhenTheDeleteFails() async {
        let server = Self.server("delete-fails")
        defer { cleanUp(server) }

        @Shared(.favorites(server)) var favorites: IdentifiedArrayOf<FavoriteDocument> = [
            .testValue(document: .testValue(id: 7))
        ]

        await #expect(throws: (any Error).self) {
            try await withDependencies {
                $0.favoritesStore.deletePDF = { _, _ in throw ApiError.testValue() }
            } operation: {
                try await RemoveFavoriteUseCase.liveValue.execute(7, server)
            }
        }

        #expect($favorites.wrappedValue[id: 7] != nil)
    }

    private func cleanUp(_ server: Server) {
        try? FileManager.default.removeItem(
            at: URL.applicationGroupDirectory.appending(component: "\(server.id)-favorites.json")
        )
    }
}
