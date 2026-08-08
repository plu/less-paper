import ApiInterface
import Dependencies
import DependenciesMacros
import Foundation
import IdentifiedCollections
import SwiftSharing

extension SetSavedViewVisibilityUseCase: @retroactive DependencyKey {
    public static let liveValue = Self(
        execute: execute(savedViewId:showInSidebar:showOnDashboard:server:)
    )
}

private extension SetSavedViewVisibilityUseCase {

    static func execute(
        savedViewId: SavedView.Id,
        showInSidebar: Bool,
        showOnDashboard: Bool,
        server: Server
    ) async throws {
        @Shared(.savedViews(server))
        var cache: IdentifiedArrayOf<SavedView> = []

        @Dependency(\.uiSettingsRepository)
        var uiSettingsRepository

        let uiSettings = try await uiSettingsRepository.getUISettings(
            input: .init(),
            server: server
        )

        var savedViews = uiSettings.settings.savedViews ?? .init()
        savedViews = .init(
            dashboardViewsVisibleIds: savedViews.dashboardViewsVisibleIds.updating(savedViewId, isIncluded: showOnDashboard),
            sidebarViewsVisibleIds: savedViews.sidebarViewsVisibleIds.updating(savedViewId, isIncluded: showInSidebar)
        )

        var settings = uiSettings.settings
        settings.savedViews = savedViews

        _ = try await uiSettingsRepository.updateUISettings(
            input: .init(settings: settings.raw),
            server: server
        )

        $cache.withLock { cache in
            cache[id: savedViewId]?.showInSidebar = showInSidebar
            cache[id: savedViewId]?.showOnDashboard = showOnDashboard
        }
    }
}

private extension [SavedView.Id] {

    func updating(_ id: SavedView.Id, isIncluded: Bool) -> Self {
        var ids = self
        ids.removeAll { $0 == id }
        if isIncluded {
            ids.append(id)
        }
        return ids
    }
}
