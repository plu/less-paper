import ApiInterface
import ComposableArchitecture
import Foundation
import ImageFeature
import Logging
import SwiftSharing
import TipsFeature
import UIKit

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

    static func runRefreshFavorites(server: Server) -> Self {
        @Dependency(\.refreshFavorites.execute) var refreshFavorites

        // Silent by design: the user did not ask for this one, so neither success nor failure is
        // surfaced. Only pull-to-refresh and "Redownload all" report.
        return .run { _ in
            _ = try? await refreshFavorites(false, server)
        }
        // Newest wins rather than first wins, and deliberately so: a launch, a foreground and a
        // pull-to-refresh all walk the same records and write the same PDF paths, and the later
        // trigger is the one with the fresher view of the world. Without this, backgrounding and
        // foregrounding repeatedly stacks refreshes, each holding a whole PDF in memory.
        .cancellable(
            id: RefreshFavoritesCancelID.refresh,
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

    // Permissions are otherwise read only at cold launch and on a server switch, so a permission
    // revoked while the app was backgrounded would stay invisible to it. The failure is swallowed
    // deliberately: the cache keeps its last value rather than being cleared, because clearing
    // swings the whole UI on a dropped connection.
    static func runRefreshPermissions(server: Server) -> Self {
        @Dependency(\.getCurrentUser.execute)
        var getCurrentUser

        @Dependency(\.log)
        var log

        return .run { _ in
            _ = try await getCurrentUser(server)
        } catch: { error, _ in
            log.warning("permissions refresh failed: \(error.localizedDescription)", category: .api)
        }
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

    // Two lines, written detached: measuring walks the caches directory and a launch must not wait
    // on it. Nothing downstream depends on the result, so there is nothing to send back.
    static func runLogLaunchContext() -> Self {
        @Dependency(\.deviceContext)
        var deviceContext

        @Dependency(\.imageCacheUsage)
        var imageCacheUsage

        @Dependency(\.log)
        var log

        @Dependency(\.storageUsage)
        var storageUsage

        return .run { _ in
            log.info(deviceContext.launchLine(), category: .app)

            let images = await imageCacheUsage.read()
            let appGroup = storageUsage.measure([.applicationGroupDirectory])
            let logFiles = storageUsage.measure(await log.fileURLs())

            log.info(
                [
                    "caches: images \(images.formatted())",
                    "app group \(appGroup.formatted())",
                    "log \(logFiles.formattedBytes())",
                ]
                .joined(separator: " · "),
                category: .app
            )
        }
    }

    // A background termination and a crash look identical from the user's side, and a memory
    // warning shortly before the log ends is the difference.
    static func runMemoryWarningObserver() -> Self {
        @Dependency(\.log)
        var log

        return .run { _ in
            let warnings = NotificationCenter.default.notifications(
                named: await UIApplication.didReceiveMemoryWarningNotification
            )
            for await _ in warnings {
                log.warning("memory warning", category: .app)
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
