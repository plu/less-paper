import ApiInterface
import ComposableArchitecture

extension Effect where Action == CorrespondentListReducer.Action {

    static func runDeleteCorrespondent(
        id: Correspondent.Id,
        server: Server
    ) -> Self {
        @Dependency(\.deleteCorrespondent.execute)
        var deleteCorrespondent

        return .run { send in
            await send(.isUpdating(id: id, isUpdating: true))
            try await deleteCorrespondent(id, server)
            await send(.correspondentDeleted(id), animation: .default)
        } catch: { error, send in
            await send(.error(error))
            await send(.isUpdating(id: id, isUpdating: false))
        }
        .cancellable(id: CancelID.deleteCorrespondent)
    }

    static func runGetCorrespondents(server: Server) -> Self {
        @Dependency(\.getCorrespondents.execute)
        var getCorrespondents

        return .run { send in
            try await send(.getCorrespondentsResult(getCorrespondents(server)), animation: .default)
            await send(.set(\.isLoaded, true))
        } catch: { error, send in
            await send(.error(error))
            await send(.set(\.isLoaded, true))
        }
        .cancellable(id: CancelID.getCorrespondents)
    }
}

private enum CancelID {
    case deleteCorrespondent
    case getCorrespondents
}
