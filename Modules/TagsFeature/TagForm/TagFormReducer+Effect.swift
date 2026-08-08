import ApiInterface
import ComposableArchitecture

extension Effect where Action == TagFormReducer.Action {

    static func runSaveTag(
        id: Tag.Id?,
        input: SaveTagInput,
        server: Server
    ) -> Self {
        @Dependency(\.saveTag.execute)
        var saveTag

        return .run { send in
            await send(.binding(.set(\.isSaving, true)))
            let tag = try await saveTag(id, input, server)
            await send(.delegate(.tagSaved(tag)), animation: .default)
            await send(.binding(.set(\.isSaving, false)))
        } catch: { error, send in
            await send(.error(error), animation: .snappy)
            await send(.binding(.set(\.isSaving, false)))
        }
        .cancellable(id: CancelID.saveTag)
    }
}

private enum CancelID {
    case saveTag
}
