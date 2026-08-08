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

        $cache.withLock { $0 = IdentifiedArray(uniqueElements: result) }

        return result
    }
}
