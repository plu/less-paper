import ApiInterface
import ComposableArchitecture

extension Effect where Action == SavedViewFormReducer.Action {

    static func runSaveSavedView(
        id: SavedView.Id?,
        input: SaveSavedViewInput,
        showInSidebar: Bool,
        showOnDashboard: Bool,
        server: Server
    ) -> Self {
        @Dependency(\.saveSavedView.execute)
        var saveSavedView

        @Dependency(\.setSavedViewVisibility.execute)
        var setSavedViewVisibility

        return .run { send in
            await send(.binding(.set(\.isSaving, true)))
            var savedView = try await saveSavedView(id, input, server)
            try await setSavedViewVisibility(savedView.id, showInSidebar, showOnDashboard, server)
            savedView.showInSidebar = showInSidebar
            savedView.showOnDashboard = showOnDashboard
            await send(.delegate(.savedViewSaved(savedView)), animation: .default)
            await send(.binding(.set(\.isSaving, false)))
        } catch: { error, send in
            await send(.error(error), animation: .snappy)
            await send(.binding(.set(\.isSaving, false)))
        }
        .cancellable(id: CancelID.saveSavedView)
    }
}

private enum CancelID {
    case saveSavedView
}
