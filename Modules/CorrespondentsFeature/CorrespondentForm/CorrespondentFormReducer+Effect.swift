import ApiInterface
import ComposableArchitecture

extension Effect where Action == CorrespondentFormReducer.Action {

    static func runSaveCorrespondent(
        id: Correspondent.Id?,
        input: SaveCorrespondentInput,
        server: Server
    ) -> Self {
        @Dependency(\.saveCorrespondent.execute)
        var saveCorrespondent

        return .run { send in
            await send(.binding(.set(\.isSaving, true)))
            let correspondent = try await saveCorrespondent(id, input, server)
            await send(.delegate(.correspondentSaved(correspondent)), animation: .default)
            await send(.binding(.set(\.isSaving, false)))
        } catch: { error, send in
            await send(.error(error), animation: .snappy)
            await send(.binding(.set(\.isSaving, false)))
        }
        .cancellable(id: CancelID.saveCorrespondent)
    }
}

private enum CancelID {
    case saveCorrespondent
}
