import ApiInterface
import Dependencies
import DependenciesMacros
import Foundation
import IdentifiedCollections
import SwiftSharing

extension GetSavedViewsUseCase: @retroactive DependencyKey {
    public static let liveValue = Self(
        execute: execute(server:)
    )
}

private extension GetSavedViewsUseCase {

    static func execute(
        server: Server
    ) async throws -> [SavedView] {
        @Shared(.apiVersion(server))
        var apiVersion: Int

        @Shared(.savedViews(server))
        var cache: IdentifiedArrayOf<SavedView> = []

        @Dependency(\.savedViewsRepository)
        var repository

        @Dependency(\.uiSettingsRepository)
        var uiSettingsRepository

        var output = try await repository.getSavedViews(
            input: .init(),
            server: server
        )
        var result = output.results

        while let url = output.next {
            output = try await repository.getSavedViews(
                input: .init(url: url),
                server: server
            )
            result.append(contentsOf: output.results)
        }

        // v10 removed show_on_dashboard/show_in_sidebar from saved views and moved them into
        // UISettings. On v9 the payload is authoritative and the extra request is pure waste.
        if apiVersion >= 10 {
            let uiSettings = try await uiSettingsRepository.getUISettings(
                input: .init(),
                server: server
            )
            let sidebarIds = Set(uiSettings.settings.savedViews?.sidebarViewsVisibleIds ?? [])
            let dashboardIds = Set(uiSettings.settings.savedViews?.dashboardViewsVisibleIds ?? [])
            result = result.map {
                var savedView = $0
                savedView.showInSidebar = sidebarIds.contains(savedView.id)
                savedView.showOnDashboard = dashboardIds.contains(savedView.id)
                return savedView
            }
        }

        $cache.withLock { $0 = IdentifiedArray(uniqueElements: result) }

        return result
    }
}
