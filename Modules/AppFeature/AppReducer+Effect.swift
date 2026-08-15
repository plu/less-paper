import ApiInterface
import ComposableArchitecture
import Foundation
import SwiftSharing

extension Effect where Action == AppReducer.Action {

    static func runSelectedServerObserver() -> Self {
        @Shared(.selectedServer)
        var selectedServer

        return .publisher {
            $selectedServer
                .publisher
                .receive(on: RunLoop.main)
                .removeDuplicates()
                .map(Action.selectedServerChanged)
        }
        .cancellable(
            id: CancelID.observeSelectedServerChanges,
            cancelInFlight: true
        )
    }

    /**
     * Re-reads the server's statistics so the Inbox tab badge reflects anything that changed while
     * the app was in the background — documents consumed from an email rule or the consumption
     * folder, or edits made from another client.
     *
     * Only statistics, not the whole cache: this runs on every foreground, and the rest of the
     * cache changes far less often than the inbox count does.
     *
     * - Parameter server: The selected server.
     */
    static func runRefreshStatistics(server: Server) -> Self {
        @Dependency(\.getStatistics.execute)
        var getStatistics

        return .run { _ in
            _ = try await getStatistics(server)
        } catch: { _, _ in
            // Best-effort: the counts keep their previous value until the next refresh.
        }
        .cancellable(
            id: CancelID.refreshStatistics,
            cancelInFlight: true
        )
    }

    static func runUpdateCache(server: Server) -> Self {
        @Dependency(\.updateCache.execute)
        var updateCache

        return .run { _ in
            try await updateCache(server)
        } catch: { _, _ in
        }
        .cancellable(
            id: CancelID.updateCache,
            cancelInFlight: true
        )
    }
}

private enum CancelID {
    case observeSelectedServerChanges
    case refreshStatistics
    case updateCache
}
