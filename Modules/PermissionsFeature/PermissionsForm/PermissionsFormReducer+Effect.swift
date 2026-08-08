import ApiInterface
import ComposableArchitecture

extension Effect where Action == PermissionsFormReducer.Action {

    static func runGetData(
        server: Server,
        type: PermissionsType?
    ) -> Self {
        @Dependency(\.getPermissions.execute)
        var getPermissions

        return .run { send in
            await send(.binding(.set(\.isLoading, true)))
            try await send(.getPermissionsResult(getPermissions(server, type)))
            await send(.binding(.set(\.isLoading, false)))
        } catch: { error, send in
            await send(.error(error))
            await send(.binding(.set(\.isLoading, false)))
        }
        .cancellable(id: CancelID.getData)
    }
}

private enum CancelID {
    case getData
}
