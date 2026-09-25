import ApiInterface
import Dependencies
import Foundation
import IdentifiedCollections
import SwiftSharing

extension RefreshOfflineUseCase: @retroactive DependencyKey {
    public static let liveValue = Self(execute: execute(force:server:))
}

private extension RefreshOfflineUseCase {

    // Long enough to be worth one request, short enough that the URL cannot be rejected.
    static let chunkSize = 100

    // Enough to be quick, not enough to hammer a home server.
    static let concurrency = 3

    static func execute(force: Bool, server: Server) async throws -> OfflineRefreshResult {
        @Dependency(\.getDocumentsByIds.execute) var getDocumentsByIds
        @Dependency(\.saveOfflineDocument.execute) var saveOfflineDocument

        @Shared(.offlineDocuments(server)) var offlineDocuments

        let stored = $offlineDocuments.wrappedValue
        guard !stored.isEmpty else {
            return OfflineRefreshResult()
        }

        // Phase one. A throw here propagates before anything is written, which is what keeps a
        // failed request from marking every offline document unavailable.
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

        $offlineDocuments.withLock { offlineDocuments in
            for offlineDocument in stored {
                // `stored` is a snapshot taken before the request. An offline document removed
                // while it was in flight must stay removed: writing it back would leave a
                // record pointing at a PDF `RemoveOfflineDocumentUseCase` has already deleted.
                guard offlineDocuments[id: offlineDocument.id] != nil else {
                    continue
                }

                guard let document = fresh[offlineDocument.id] else {
                    // The flag is set either way; only the transition is counted. An offline
                    // document that was already missing is not news, and reporting it again would
                    // put an error toast ahead of "N offline documents updated" on every manual
                    // refresh from here on — the same stale complaint forever, and never a word
                    // about the real work.
                    if !offlineDocument.isUnavailable {
                        unavailable += 1
                    }
                    offlineDocuments[id: offlineDocument.id]?.isUnavailable = true
                    continue
                }

                // Written back unconditionally: bulk edit changes fields without moving `modified`.
                // `syncedModified` is carried rather than advanced — the notes, metadata and PDF
                // have not been fetched yet, and phase two may still fail to fetch them.
                //
                // The stored `content` is carried too. This document came from `id__in`, which
                // paperless truncates, so copying its `content` over would replace the whole text
                // with a preview of it. Anything that genuinely changes content moves `modified`,
                // so phase two is what refreshes it.
                offlineDocuments[id: offlineDocument.id] = OfflineDocument(
                    document: document.with(content: offlineDocument.document.content),
                    metadata: offlineDocument.metadata,
                    notes: offlineDocument.notes,
                    pdfByteCount: offlineDocument.pdfByteCount,
                    storedAt: offlineDocument.storedAt,
                    syncedModified: offlineDocument.syncedModified,
                    isUnavailable: false
                )

                if force || document.modified != offlineDocument.syncedModified {
                    changed.append(document)
                }
            }
        }

        // Bound to a `let` first: `@Dependency` declares a mutable backing var, which a task
        // group's sending closure is not allowed to capture.
        let save = saveOfflineDocument

        // Phase two.
        // A sliding window: `concurrency` tasks in flight, and each one that finishes starts the
        // next. `withTaskGroup(of:)` would otherwise run all of them at once.
        let failed = await withTaskGroup(of: Bool.self) { group in
            var iterator = changed.makeIterator()
            var failures = 0

            func addNext() {
                guard let document = iterator.next() else {
                    return
                }
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
                if !succeeded {
                    failures += 1
                }
                addNext()
            }

            return failures
        }

        return OfflineRefreshResult(
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
