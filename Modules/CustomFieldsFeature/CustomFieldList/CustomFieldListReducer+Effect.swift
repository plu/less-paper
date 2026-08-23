import ApiInterface
import ComposableArchitecture

extension Effect where Action == CustomFieldListReducer.Action {

    static func runDeleteCustomField(
        id: CustomField.Id,
        server: Server
    ) -> Self {
        @Dependency(\.deleteCustomField.execute)
        var deleteCustomField

        return .run { send in
            await send(.isUpdating(id: id, isUpdating: true))
            try await deleteCustomField(id, server)
            await send(.customFieldDeleted(id), animation: .default)
        } catch: { error, send in
            await send(.error(error))
            await send(.isUpdating(id: id, isUpdating: false))
        }
        .cancellable(id: CancelID.deleteCustomField)
    }

    static func runGetCustomFields(server: Server) -> Self {
        @Dependency(\.getCustomFields.execute)
        var getCustomFields

        return .run { send in
            try await send(.getCustomFieldsResult(getCustomFields(server)), animation: .default)
            await send(.set(\.isLoaded, true))
        } catch: { error, send in
            await send(.error(error))
            await send(.set(\.isLoaded, true))
        }
        .cancellable(id: CancelID.getCustomFields)
    }
}

private enum CancelID {
    case deleteCustomField
    case getCustomFields
}
