import ApiInterface
import Components
import ComposableArchitecture
import Foundation
// Only the type, not the module: a plain `import SwiftUI` makes `Document` ambiguous against
// `ApiInterface.Document` throughout this file.
import struct SwiftUI.Animation

extension Effect where Action == DocumentListReducer.Action {

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



    // The same three-way refresh after either direction of the swipe. `runGetDocuments` is what
    // drops the row out of the inbox filter (or puts it back); the statistics fetch is here because
    // the tab badge reads `inboxDocumentCount`, which nothing else on this path writes, so without
    // it the number sits still while rows leave the list underneath it.
    static func runInboxTagsRefresh(
        state: DocumentListReducer.State,
        document: Document.Id
    ) -> Self {
        .merge(
            .runGetDocuments(
                // One row leaves the filter here, or comes back to it, so it is worth animating -
                // unlike the refetches this helper's default is tuned for.
                animation: .default,
                filterRules: state.filter.input.filterRules,
                server: state.server,
                sortDirection: state.filter.input.sort.direction,
                sortField: state.filter.input.sort.field
            ),
            .runRefreshDocuments(
                ids: Set(state.documentCache.ids).intersection([document]),
                server: state.server
            ),
            .runRefreshStatistics(server: state.server)
        )
    }


    // Unanimated by default because most callers are a wholesale replacement - a pull to refresh, a
    // sort change, another page - where animating every row that moved is noise rather than
    // feedback. A caller that knows exactly one row is leaving or arriving passes `.default`.
    static func runGetDocuments(
        animation: Animation? = .none,
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
            try await send(.replaceDocuments(getDocuments(input, server)), animation: animation)
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

    static func runConfirmDeleteSelected(documentCount: Int) -> Self {
        @Dependency(\.documentDeleteConfirmation.presentMany)
        var presentConfirmation

        return .run { send in
            guard await presentConfirmation(documentCount) else {
                return
            }
            await send(.deleteSelectedConfirmed)
        }
        .cancellable(id: CancelID.confirmDeleteSelected)
    }

    static func runRefreshStatistics(server: Server) -> Self {
        @Dependency(\.getStatistics.execute)
        var getStatistics

        return .run { _ in
            _ = try await getStatistics(server)
        } catch: { _, _ in
            // Best-effort, exactly like `runRefreshDocuments` below: a failure here must not
            // surface an error for a refresh the user did not explicitly ask for.
        }
        .cancellable(id: CancelID.refreshStatistics)
    }

    static func runRefreshFailedFileTaskCount(server: Server) -> Self {
        @Dependency(\.getFailedFileTaskCount.execute)
        var getFailedFileTaskCount

        return .run { _ in
            _ = try await getFailedFileTaskCount(server)
        } catch: { _, _ in
            // Best-effort, like runRefreshStatistics above: the badge keeps its previous number
            // rather than reporting zero for a request that failed.
        }
        .cancellable(id: CancelID.refreshFailedFileTaskCount, cancelInFlight: true)
    }

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

    static func runCheckTipInvitation() -> Self {
        @Dependency(\.tipInvitation.isEligible)
        var isEligible

        return .run { send in
            await send(.tipInvitationEligible(isEligible()), animation: .default)
        }
    }

    static func runSettleTipInvitation() -> Self {
        @Dependency(\.tipInvitation.settle)
        var settle

        return .run { _ in
            await settle()
        }
    }

    static func runSelectServer(server: Server) -> Self {
        .run { _ in
            @Shared(.selectedServer)
            var selectedServer: Server?

            // An effect rather than a synchronous write: this is what makes `AppReducer` discard
            // `MainReducer.State`, and with it the store currently being reduced.
            $selectedServer.withLock { $0 = server }
        }
        .cancellable(
            id: CancelID.selectServer,
            cancelInFlight: true
        )
    }
}

private let refreshChunkSize = 100

private enum CancelID: Hashable {
    case confirmDeleteSelected
    case deleteDocuments
    case getDocuments
    case getMoreDocuments
    case refreshDocuments
    case refreshFailedFileTaskCount
    case refreshStatistics
    case selectServer
}
