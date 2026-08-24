import ApiInterface
import ComposableArchitecture

extension Effect where Action == SavedViewFormReducer.Action {

    static func runSaveSavedView(
        id: SavedView.Id?,
        input: SaveSavedViewInput,
        server: Server
    ) -> Self {
        @Dependency(\.saveSavedView.execute)
        var saveSavedView

        return .run { send in
            await send(.binding(.set(\.isSaving, true)))
            let savedView = try await saveSavedView(id, input, server)
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
