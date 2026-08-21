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
        @Shared(.apiVersion(server))
        var apiVersion: Int

        @Shared(.savedViews(server))
        var cache: IdentifiedArrayOf<SavedView> = []

        // v10 removed these fields from the saved view serializer; v9 has no saved_views entry in
        // UISettings, so writing there would be silently discarded.
        if apiVersion >= 10 {
            try await updateUISettings(
                savedViewId: savedViewId,
                showInSidebar: showInSidebar,
                showOnDashboard: showOnDashboard,
                server: server
            )
        } else {
            @Dependency(\.savedViewsRepository)
            var savedViewsRepository

            _ = try await savedViewsRepository.setSavedViewVisibility(
                id: savedViewId,
                input: .init(showInSidebar: showInSidebar, showOnDashboard: showOnDashboard),
                server: server
            )
        }

        $cache.withLock { cache in
            cache[id: savedViewId]?.showInSidebar = showInSidebar
            cache[id: savedViewId]?.showOnDashboard = showOnDashboard
        }
    }

    static func updateUISettings(
        savedViewId: SavedView.Id,
        showInSidebar: Bool,
        showOnDashboard: Bool,
        server: Server
    ) async throws {
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
