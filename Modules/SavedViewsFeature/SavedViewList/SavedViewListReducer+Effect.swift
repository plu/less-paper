import ApiInterface
import ComposableArchitecture

extension Effect where Action == SavedViewListReducer.Action {

    static func runDeleteSavedView(
        id: SavedView.Id,
        server: Server
    ) -> Self {
        @Dependency(\.deleteSavedView.execute)
        var deleteSavedView

        return .run { send in
            await send(.isUpdating(id: id, isUpdating: true))
            try await deleteSavedView(id, server)
            await send(.savedViewDeleted(id), animation: .default)
        } catch: { error, send in
            await send(.error(error))
            await send(.isUpdating(id: id, isUpdating: false))
        }
        .cancellable(id: CancelID.deleteSavedView)
    }

    static func runGetSavedViews(server: Server) -> Self {
        @Dependency(\.getSavedViews.execute)
        var getSavedViews

        return .run { send in
            try await send(.getSavedViewsResult(getSavedViews(server)), animation: .default)
            await send(.set(\.isLoaded, true))
        } catch: { error, send in
            await send(.error(error))
            await send(.set(\.isLoaded, true))
        }
        .cancellable(id: CancelID.getSavedViews)
    }
}

private enum CancelID {
    case deleteSavedView
    case getSavedViews
}
