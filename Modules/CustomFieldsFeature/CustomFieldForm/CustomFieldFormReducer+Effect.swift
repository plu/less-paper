import ApiInterface
import ComposableArchitecture

extension Effect where Action == CustomFieldFormReducer.Action {

    static func runSaveCustomField(
        id: CustomField.Id?,
        input: SaveCustomFieldInput,
        server: Server
    ) -> Self {
        @Dependency(\.saveCustomField.execute)
        var saveCustomField

        return .run { send in
            await send(.binding(.set(\.isSaving, true)))
            let customField = try await saveCustomField(id, input, server)
            await send(.delegate(.customFieldSaved(customField)), animation: .default)
            await send(.binding(.set(\.isSaving, false)))
        } catch: { error, send in
            await send(.error(error), animation: .snappy)
            await send(.binding(.set(\.isSaving, false)))
        }
        .cancellable(id: CancelID.saveCustomField)
    }
}

private enum CancelID {
    case saveCustomField
}
