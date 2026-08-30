import ApiInterface
import Dependencies
import Foundation
import IdentifiedCollections
import SwiftSharing
import Testing

@Suite
struct RefreshFavoritesUseCaseTests {

    private static let stored = Date(timeIntervalSince1970: 1_000)

    // A server per test, so the shared favorites file cannot collide under swift-testing's
    // in-suite parallelism.
    private static func server(_ name: String) -> Server {
        .testValue(id: "refresh-favorites-use-case-tests-\(name)")
    }

    @Test
    func test_unchangedModifiedFetchesNothingExpensive() async throws {
        let server = Self.server("unchanged-modified")
        defer { cleanUp(server) }

        let document = Document.testValue(id: 7, modified: Self.stored)
        let saved = LockIsolated(0)

        @Shared(.favorites(server)) var favorites: IdentifiedArrayOf<FavoriteDocument> = [
            .testValue(document: document)
        ]

        let result = try await withDependencies {
            $0.getDocumentsByIds.execute = { _, _ in [document] }
            $0.saveFavorite.execute = { _, _, _ in saved.withValue { $0 += 1 } }
        } operation: {
            try await RefreshFavoritesUseCase.liveValue.execute(false, server)
        }

        #expect(saved.value == 0)
        #expect(result.updated == 0)
    }

    @Test
    func test_movedModifiedRefetchesEverything() async throws {
        let server = Self.server("moved-modified")
        defer { cleanUp(server) }

        let fresh = Document.testValue(id: 7, modified: Self.stored.addingTimeInterval(60))
        let saved = LockIsolated(0)

        @Shared(.favorites(server)) var favorites: IdentifiedArrayOf<FavoriteDocument> = [
            .testValue(document: .testValue(id: 7, modified: Self.stored))
        ]

        let result = try await withDependencies {
            $0.getDocumentsByIds.execute = { _, _ in [fresh] }
            $0.saveFavorite.execute = { _, _, _ in saved.withValue { $0 += 1 } }
        } operation: {
            try await RefreshFavoritesUseCase.liveValue.execute(false, server)
        }

        #expect(saved.value == 1)
        #expect(result.updated == 1)
    }

    // bulk_edit changes tags and correspondent through QuerySet.update(), which bypasses Django's
    // auto_now, so `modified` does not move. The document from phase one is written back anyway,
    // and this is the test that catches anyone "simplifying" that away.
    @Test
    func test_fieldsChangedWithoutModifiedMovingAreStillStored() async throws {
        let server = Self.server("fields-changed")
        defer { cleanUp(server) }

        let fresh = Document.testValue(id: 7, modified: Self.stored, title: "Renamed")
        let saved = LockIsolated(0)

        @Shared(.favorites(server)) var favorites: IdentifiedArrayOf<FavoriteDocument> = [
            .testValue(document: .testValue(id: 7, modified: Self.stored, title: "Old"))
        ]

        _ = try await withDependencies {
            $0.getDocumentsByIds.execute = { _, _ in [fresh] }
            $0.saveFavorite.execute = { _, _, _ in saved.withValue { $0 += 1 } }
        } operation: {
            try await RefreshFavoritesUseCase.liveValue.execute(false, server)
        }

        #expect($favorites.wrappedValue[id: 7]?.document.title == "Renamed")
        #expect(saved.value == 0)
    }

    // Phase one's write-back takes its document from `id__in`, which paperless truncates. Copying
    // that `content` over would throw away the full text the save fetched, and phase two would not
    // put it back: nothing that genuinely changes content leaves `modified` where it was, so an
    // unchanged `modified` means the stored content is still the right one.
    @Test
    func test_phaseOneKeepsTheStoredContent() async throws {
        let server = Self.server("keeps-stored-content")
        defer { cleanUp(server) }

        let full = "The quick brown fox jumped over the lazy dog"
        let fresh = Document.testValue(content: "The quick brown fox jum", id: 7, modified: Self.stored, title: "Renamed")

        @Shared(.favorites(server)) var favorites: IdentifiedArrayOf<FavoriteDocument> = [
            .testValue(document: .testValue(content: full, id: 7, modified: Self.stored, title: "Old"))
        ]

        _ = try await withDependencies {
            $0.getDocumentsByIds.execute = { _, _ in [fresh] }
            $0.saveFavorite.execute = { _, _, _ in }
        } operation: {
            try await RefreshFavoritesUseCase.liveValue.execute(false, server)
        }

        #expect($favorites.wrappedValue[id: 7]?.document.title == "Renamed")
        #expect($favorites.wrappedValue[id: 7]?.document.content == full)
    }

    @Test
    func test_anIdMissingFromTheResponseIsMarkedUnavailable() async throws {
        let server = Self.server("missing-id")
        defer { cleanUp(server) }

        @Shared(.favorites(server)) var favorites: IdentifiedArrayOf<FavoriteDocument> = [
            .testValue(document: .testValue(id: 7))
        ]

        let result = try await withDependencies {
            $0.getDocumentsByIds.execute = { _, _ in [] }
        } operation: {
            try await RefreshFavoritesUseCase.liveValue.execute(false, server)
        }

        #expect($favorites.wrappedValue[id: 7]?.isUnavailable == true)
        #expect(result.unavailable == 1)
    }

    // The count is what the manual refresh reports, and it reports news: a favorite already badged
    // stays badged and stays silent, or one deleted document would push an error toast ahead of
    // every later "N favorites updated".
    @Test
    func test_aFavoriteAlreadyUnavailableIsNotCountedAgain() async throws {
        let server = Self.server("already-unavailable")
        defer { cleanUp(server) }

        @Shared(.favorites(server)) var favorites: IdentifiedArrayOf<FavoriteDocument> = [
            .testValue(document: .testValue(id: 7), isUnavailable: true),
            .testValue(document: .testValue(id: 8)),
        ]

        let result = try await withDependencies {
            $0.getDocumentsByIds.execute = { _, _ in [] }
        } operation: {
            try await RefreshFavoritesUseCase.liveValue.execute(false, server)
        }

        #expect(result.unavailable == 1)
        #expect($favorites.wrappedValue[id: 7]?.isUnavailable == true)
        #expect($favorites.wrappedValue[id: 8]?.isUnavailable == true)
    }

    // The one that matters most: a failed request knows nothing about what the server holds.
    // Marking on failure would badge every favorite the first time the app opens on a plane.
    @Test
    func test_aFailedPhaseOneMarksNothing() async {
        let server = Self.server("failed-phase-one")
        defer { cleanUp(server) }

        @Shared(.favorites(server)) var favorites: IdentifiedArrayOf<FavoriteDocument> = [
            .testValue(document: .testValue(id: 7))
        ]

        await #expect(throws: (any Error).self) {
            try await withDependencies {
                $0.getDocumentsByIds.execute = { _, _ in throw ApiError.testValue() }
            } operation: {
                try await RefreshFavoritesUseCase.liveValue.execute(false, server)
            }
        }

        #expect($favorites.wrappedValue[id: 7]?.isUnavailable == false)
    }

    @Test
    func test_forceRefetchesEvenWhenModifiedIsUnchanged() async throws {
        let server = Self.server("force")
        defer { cleanUp(server) }

        let document = Document.testValue(id: 7, modified: Self.stored)
        let saved = LockIsolated(0)

        @Shared(.favorites(server)) var favorites: IdentifiedArrayOf<FavoriteDocument> = [
            .testValue(document: document)
        ]

        _ = try await withDependencies {
            $0.getDocumentsByIds.execute = { _, _ in [document] }
            $0.saveFavorite.execute = { _, _, _ in saved.withValue { $0 += 1 } }
        } operation: {
            try await RefreshFavoritesUseCase.liveValue.execute(true, server)
        }

        #expect(saved.value == 1)
    }

    // Phase one works from a snapshot taken before the request. Writing that snapshot back
    // wholesale would resurrect a favorite the user removed while the request was in flight —
    // as a record pointing at a PDF `RemoveFavoriteUseCase` has already deleted.
    @Test
    func test_aFavoriteRemovedDuringPhaseOneIsNotResurrected() async throws {
        let server = Self.server("removed-mid-flight")
        defer { cleanUp(server) }

        @Shared(.favorites(server)) var favorites: IdentifiedArrayOf<FavoriteDocument> = [
            .testValue(document: .testValue(id: 7))
        ]
        let shared = $favorites

        _ = try await withDependencies {
            $0.getDocumentsByIds.execute = { _, _ in
                shared.withLock { _ = $0.remove(id: 7) }
                return [.testValue(id: 7)]
            }
        } operation: {
            try await RefreshFavoritesUseCase.liveValue.execute(false, server)
        }

        #expect($favorites.wrappedValue[id: 7] == nil)
    }

    @Test
    func test_aFailedSaveIsCountedAndNotReportedAsUpdated() async throws {
        let server = Self.server("failed-save")
        defer { cleanUp(server) }

        let fresh = Document.testValue(id: 7, modified: Self.stored.addingTimeInterval(60))

        @Shared(.favorites(server)) var favorites: IdentifiedArrayOf<FavoriteDocument> = [
            .testValue(document: .testValue(id: 7, modified: Self.stored))
        ]

        let result = try await withDependencies {
            $0.getDocumentsByIds.execute = { _, _ in [fresh] }
            $0.saveFavorite.execute = { _, _, _ in throw ApiError.testValue() }
        } operation: {
            try await RefreshFavoritesUseCase.liveValue.execute(false, server)
        }

        #expect(result.failed == 1)
        #expect(result.updated == 0)
    }

    // A failed phase two must not hide itself. Phase one has already stored the server's new
    // `modified`, so a gate comparing against that would find them equal on the next refresh and
    // never retry the notes, metadata and PDF that failed to download — the favorite would stay
    // stale until someone hit "Redownload all".
    @Test
    func test_aFailedSaveIsRetriedByTheNextRefresh() async throws {
        let server = Self.server("failed-save-retried")
        defer { cleanUp(server) }

        let fresh = Document.testValue(id: 7, modified: Self.stored.addingTimeInterval(60))
        let attempts = LockIsolated(0)

        @Shared(.favorites(server)) var favorites: IdentifiedArrayOf<FavoriteDocument> = [
            .testValue(document: .testValue(id: 7, modified: Self.stored))
        ]

        _ = try await withDependencies {
            $0.getDocumentsByIds.execute = { _, _ in [fresh] }
            $0.saveFavorite.execute = { _, _, _ in
                attempts.withValue { $0 += 1 }
                throw ApiError.testValue()
            }
        } operation: {
            try await RefreshFavoritesUseCase.liveValue.execute(false, server)
        }

        let second = try await withDependencies {
            $0.getDocumentsByIds.execute = { _, _ in [fresh] }
            $0.saveFavorite.execute = { _, _, _ in attempts.withValue { $0 += 1 } }
        } operation: {
            try await RefreshFavoritesUseCase.liveValue.execute(false, server)
        }

        #expect(attempts.value == 2)
        #expect(second.updated == 1)
    }

    @Test
    func test_everyIdIsRequestedOnceAcrossTheChunkBoundary() async throws {
        let server = Self.server("chunk-boundary")
        defer { cleanUp(server) }

        let ids = (1 ... 101).map { Document.Id(rawValue: $0) }
        let requested = LockIsolated<[Document.Id]>([])
        let chunkSizes = LockIsolated<[Int]>([])

        @Shared(.favorites(server)) var favorites = IdentifiedArrayOf<FavoriteDocument>(
            uniqueElements: ids.map { .testValue(document: .testValue(id: $0)) }
        )

        _ = try await withDependencies {
            $0.getDocumentsByIds.execute = { input, _ in
                requested.withValue { $0.append(contentsOf: input.ids) }
                chunkSizes.withValue { $0.append(input.ids.count) }
                return []
            }
        } operation: {
            try await RefreshFavoritesUseCase.liveValue.execute(false, server)
        }

        #expect(chunkSizes.value == [100, 1])
        #expect(requested.value.sorted() == ids)
    }

    private func cleanUp(_ server: Server) {
        try? FileManager.default.removeItem(
            at: URL.applicationGroupDirectory.appending(component: "\(server.id)-favorites.json")
        )
    }
}
