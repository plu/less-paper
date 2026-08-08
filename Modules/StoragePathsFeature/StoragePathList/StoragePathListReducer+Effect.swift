import ApiInterface
import ComposableArchitecture

extension Effect where Action == StoragePathListReducer.Action {

    static func runDeleteStoragePath(
        id: StoragePath.Id,
        server: Server
    ) -> Self {
        @Dependency(\.deleteStoragePath.execute)
        var deleteStoragePath

        return .run { send in
            await send(.isUpdating(id: id, isUpdating: true))
            try await deleteStoragePath(id, server)
            await send(.storagePathDeleted(id), animation: .default)
        } catch: { error, send in
            await send(.error(error))
            await send(.isUpdating(id: id, isUpdating: false))
        }
        .cancellable(id: CancelID.deleteStoragePath)
    }

    static func runGetStoragePaths(server: Server) -> Self {
        @Dependency(\.getStoragePaths.execute)
        var getStoragePaths

        return .run { send in
            try await send(.getStoragePathsResult(getStoragePaths(server)), animation: .default)
            await send(.set(\.isLoaded, true))
        } catch: { error, send in
            await send(.error(error))
            await send(.set(\.isLoaded, true))
        }
        .cancellable(id: CancelID.getStoragePaths)
    }
}

private enum CancelID {
    case deleteStoragePath
    case getStoragePaths
}
