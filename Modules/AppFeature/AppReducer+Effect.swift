import ApiInterface
import ComposableArchitecture
import Foundation
import SwiftSharing
import TipsFeature

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

    // For the whole life of the app, not the life of the tip screen: a purchase approved through
    // Ask to Buy arrives long after that screen is gone, and TipJar has already finished the
    // transaction by the time it reaches here.
    static func runTipObserver() -> Self {
        @Dependency(\.tipJar.updates)
        var updates

        return .run { send in
            for await tip in updates() {
                await send(.tipReceived(tip))
            }
        }
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
