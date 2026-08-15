import ApiInterface
import ComposableArchitecture
import Foundation

extension Effect where Action == DocumentFilterReducer.Action {

    static func runDismiss() -> Self {
        .run { _ in
            @Dependency(\.dismiss)
            var dismiss

            await dismiss()
        }
    }

    static func runFilterUpdated(_ state: DocumentFilterReducer.State) -> Self {
        .merge(
            .cancel(id: CancelID.searchDebounce),
            .send(.delegate(.filterUpdated(.init(
                input: state.input,
                savedView: state.savedView
            ))))
        )
    }

    static func runSaveView(
        filterRules: [FilterRule],
        savedView: SavedView,
        server: Server,
        sortDirection: SortDirection,
        sortField: SortField
    ) -> Self {
        .run { send in
            @Dependency(\.saveSavedView.execute)
            var saveSavedView

            var input = SaveSavedViewInput(savedView: savedView)

            input.filterRules = filterRules
            input.sortField = sortField
            input.sortReverse = sortDirection.sortReverse

            try await send(.savedViewSaved(saveSavedView(savedView.id, input, server)))
        } catch: { error, send in
            await send(.error(error))
        }
        .cancellable(id: CancelID.saveView)
    }

    // Carries no filter on purpose: the reducer reads state when `searchDebounced` lands. Capturing
    // it here would let a keystroke report a search type the user changed inside the window.
    static func runSearchDebounce() -> Self {
        @Dependency(\.continuousClock)
        var clock

        return .run { send in
            try await clock.sleep(for: .milliseconds(400))
            await send(.searchDebounced)
        }
        .cancellable(id: CancelID.searchDebounce, cancelInFlight: true)
    }
}

private enum CancelID {
    case saveView
    case searchDebounce
}
