import ApiInterface
import Dependencies
import DependenciesMacros
import Foundation
import IdentifiedCollections
import SwiftSharing

extension SaveSavedViewUseCase: @retroactive DependencyKey {
    public static let liveValue = Self(
        execute: execute(id:input:server:)
    )
}

private extension SaveSavedViewUseCase {

    static func execute(
        id: SavedView.Id?,
        input: SaveSavedViewInput,
        server: Server
    ) async throws -> SaveSavedViewOutput {
        @Shared(.apiVersion(server))
        var apiVersion: Int?

        // Not yet negotiated reads as the oldest server this app supports: the newer shape is the
        // one that has to be earned by a version we have actually seen.
        let version = apiVersion ?? ApiVersion.minimumSupported

        @Shared(.savedViews(server))
        var cache: IdentifiedArrayOf<SavedView> = []

        @Dependency(\.savedViewsRepository)
        var savedViewsRepository

        // v10 moved show_in_sidebar/show_on_dashboard out of the saved view serializer and into
        // UISettings. Older versions require both on create, so there they have to ride along in
        // the body — a POST without them is rejected before anything else can set them.
        var body = input
        if version >= 10 {
            body.showInSidebar = nil
            body.showOnDashboard = nil
        }

        var result: SaveSavedViewOutput

        if let id {
            result = try await savedViewsRepository.updateSavedView(
                id: id,
                input: body,
                server: server
            )
        } else {
            result = try await savedViewsRepository.createSavedView(
                input: body,
                server: server
            )
        }

        if version >= 10,
           let showInSidebar = input.showInSidebar,
           let showOnDashboard = input.showOnDashboard {
            try await updateUISettings(
                savedViewId: result.id,
                showInSidebar: showInSidebar,
                showOnDashboard: showOnDashboard,
                server: server
            )
            result.showInSidebar = showInSidebar
            result.showOnDashboard = showOnDashboard
        }

        $cache.withLock { cache in
            cache.updateOrAppend(result)
            cache.sort {
                $0.name.compare(
                    $1.name,
                    options: [
                        .caseInsensitive,
                        .numeric,
                        .forcedOrdering
                    ]
                ) == .orderedAscending
            }
        }

        return result
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
