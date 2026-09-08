import ComposableArchitecture
import Intelligence

extension Effect where Action == DocumentTitleSuggestionsReducer.Action {

    static func runDismiss() -> Self {
        .run { _ in
            @Dependency(\.dismiss)
            var dismiss

            await dismiss()
        }
    }

    static func runSuggest(context: TitleSuggestionContext) -> Self {
        .run { send in
            @Dependency(\.titleSuggestion.suggest)
            var suggest

            for try await suggestions in suggest(context) {
                await send(.suggestionsUpdated(suggestions))
            }
            await send(.generationFinished(nil))
        } catch: { error, send in
            await send(.generationFinished(error as? TitleSuggestionError ?? .failed(error.localizedDescription)))
        }
        // Regenerate replaces the run in flight, and dismissing the sheet ends it, so a stream
        // cannot outlive the sheet that started it.
        .cancellable(id: CancelID.suggest, cancelInFlight: true)
    }
}

private enum CancelID {
    case suggest
}
