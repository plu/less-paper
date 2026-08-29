import ApiInterface
import Dependencies
import Foundation
import IdentifiedCollections
import SwiftSharing

extension RefreshFavoritesUseCase: @retroactive DependencyKey {
    public static let liveValue = Self(execute: execute(force:server:))
}

private extension RefreshFavoritesUseCase {

    // Long enough to be worth one request, short enough that the URL cannot be rejected.
    static let chunkSize = 100

    // Enough to be quick, not enough to hammer a home server.
    static let concurrency = 3

    static func execute(force: Bool, server: Server) async throws -> FavoriteRefreshResult {
        @Dependency(\.getDocumentsByIds.execute) var getDocumentsByIds
        @Dependency(\.saveFavorite.execute) var saveFavorite

        @Shared(.favorites(server)) var favorites

        let stored = $favorites.wrappedValue
        guard !stored.isEmpty else {
            return FavoriteRefreshResult()
        }

        // Phase one. A throw here propagates before anything is written, which is what keeps a
        // failed request from marking every favorite unavailable.
        var fresh: [Document.Id: Document] = [:]
        for chunk in stored.ids.chunked(into: chunkSize) {
            let documents = try await getDocumentsByIds(
                GetDocumentsByIdsInput(ids: chunk),
                server
            )
            for document in documents {
                fresh[document.id] = document
            }
        }

        var changed: [Document] = []
        var unavailable = 0

        $favorites.withLock { favorites in
            for favorite in stored {
                // `stored` is a snapshot taken before the request. A favorite removed while it was
                // in flight must stay removed: writing it back would leave a record pointing at a
                // PDF `RemoveFavoriteUseCase` has already deleted.
                guard favorites[id: favorite.id] != nil else {
                    continue
                }

                guard let document = fresh[favorite.id] else {
                    favorites[id: favorite.id]?.isUnavailable = true
                    unavailable += 1
                    continue
                }

                // Written back unconditionally: bulk edit changes fields without moving `modified`.
                favorites[id: favorite.id] = FavoriteDocument(
                    document: document,
                    metadata: favorite.metadata,
                    notes: favorite.notes,
                    pdfByteCount: favorite.pdfByteCount,
                    storedAt: favorite.storedAt,
                    isUnavailable: false
                )

                if force || document.modified != favorite.document.modified {
                    changed.append(document)
                }
            }
        }

        // Bound to a `let` first: `@Dependency` declares a mutable backing var, which a task
        // group's sending closure is not allowed to capture.
        let save = saveFavorite

        // Phase two.
        // A sliding window: `concurrency` tasks in flight, and each one that finishes starts the
        // next. `withTaskGroup(of:)` would otherwise run all of them at once.
        let failed = await withTaskGroup(of: Bool.self) { group in
            var iterator = changed.makeIterator()
            var failures = 0

            func addNext() {
                guard let document = iterator.next() else { return }
                group.addTask {
                    do {
                        try await save(document, server, .refreshExisting)
                        return true
                    } catch {
                        return false
                    }
                }
            }

            for _ in 0 ..< concurrency { addNext() }

            while let succeeded = await group.next() {
                if !succeeded { failures += 1 }
                addNext()
            }

            return failures
        }

        return FavoriteRefreshResult(
            failed: failed,
            unavailable: unavailable,
            updated: changed.count - failed
        )
    }
}

private extension Collection {

    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map { offset in
            let start = index(startIndex, offsetBy: offset)
            let end = index(start, offsetBy: size, limitedBy: endIndex) ?? endIndex
            return Array(self[start ..< end])
        }
    }
}
