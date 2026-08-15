import ApiInterface
import ComposableArchitecture
import Foundation

extension Effect where Action == DocumentListReducer.Action {

    /**
     * Deletes documents on the server, then announces the removal locally and to the other tab.
     *
     * The rows are dimmed for the duration rather than removed optimistically, so a failure
     * leaves the list exactly as it was.
     *
     * - Parameters:
     *   - ids: The documents to delete.
     *   - server: The server to delete them from.
     */
    static func runDeleteDocuments(
        ids: Set<Document.Id>,
        server: Server
    ) -> Self {
        @Dependency(\.deleteDocuments.execute)
        var deleteDocuments

        return .run { send in
            await send(.isUpdating(ids: ids, isUpdating: true))
            try await deleteDocuments(ids.sorted(), server)
            await send(.documentsDeleted(ids), animation: .default)
            await send(.delegate(.documentsDeleted(ids)))
        } catch: { error, send in
            await send(.deleteDocumentsFailed(ids: ids, error: error))
        }
        .cancellable(id: CancelID.deleteDocuments)
    }

    static func runGetDocuments(
        filterRules: [FilterRule] = [],
        server: Server,
        sortDirection: SortDirection,
        sortField: SortField
    ) -> Self {
        @Dependency(\.getDocuments.execute)
        var getDocuments

        let input = GetDocumentsInput(
            filterRules: filterRules,
            sortDirection: sortDirection,
            sortField: sortField
        )

        return .run { send in
            try await send(.replaceDocuments(getDocuments(input, server)), animation: .none)
            await send(.set(\.isLoaded, true))
        } catch: { error, send in
            await send(.error(error))
            await send(.set(\.isLoaded, true))
        }
        .cancellable(id: CancelID.getDocuments)
    }

    static func runGetMoreDocuments(
        server: Server,
        url: URL
    ) -> Self {
        @Dependency(\.getDocuments.execute)
        var getDocuments

        return .run { send in
            try await send(.appendDocuments(getDocuments(.init(url: url), server)), animation: .none)
            await send(.set(\.isLoadingMore, false))
        } catch: { error, send in
            await send(.error(error))
            await send(.set(\.isLoadingMore, false))
        }
        .cancellable(id: CancelID.getDocuments)
    }

    /**
     * Re-fetches the given documents and writes them into the shared store.
     *
     * Bulk edit returns no documents, so the affected content has to be re-read. Only ids
     * already present in the store are worth fetching, and the request is chunked because a
     * selection can run to thousands of ids.
     *
     * - Parameters:
     *   - ids: The affected document ids that are present in the shared store.
     *   - server: The server to fetch from.
     */
    static func runRefreshDocuments(
        ids: Set<Document.Id>,
        server: Server
    ) -> Self {
        @Dependency(\.getDocumentsByIds.execute)
        var getDocumentsByIds

        guard !ids.isEmpty else {
            return .none
        }

        let chunks = ids.sorted().chunked(into: refreshChunkSize)

        return .run { send in
            for chunk in chunks {
                let documents = try await getDocumentsByIds(.init(ids: chunk), server)
                await send(.documentsRefreshed(documents), animation: .none)
            }
        } catch: { _, _ in
            // Best-effort content sync. A failure leaves the affected rows showing their
            // previous content until the next fetch. Sending `.error` here would set
            // `state.error` and surface the empty-state view, which would be wrong.
        }
        .cancellable(id: CancelID.refreshDocuments)
    }
}

private let refreshChunkSize = 100

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}

private enum CancelID {
    case deleteDocuments
    case getDocuments
    case getMoreDocuments
    case refreshDocuments
}
