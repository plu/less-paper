import ApiInterface
import ComposableArchitecture

extension Effect where Action == ServerFormReducer.Action {

    static func runSaveServer(
        input: ServerFormInput
    ) -> Self {
        @Dependency(\.negotiateApiVersion.execute)
        var negotiateApiVersion

        @Dependency(\.storeToken.execute)
        var storeToken

        @Dependency(\.updateCache.execute)
        var updateCache

        return .run { send in
            await send(.binding(.set(\.isSaving, true)))
            try await storeToken(input.code, input.password, input.server, input.username)
            _ = try await negotiateApiVersion(input.server)
            try await updateCache(input.server)
            await send(.delegate(.serverSaved(input.server)), animation: .default)
            await send(.binding(.set(\.isSaving, false)))
        } catch: { error, send in
            if error.isMfaCodeRequiredError {
                await send(.mfaCodeRequired)
                return
            }
            await send(.error(error))
            await send(.binding(.set(\.isSaving, false)))
        }
        .cancellable(id: CancelID.saveServer)
    }
}

private enum CancelID {
    case saveServer
}
