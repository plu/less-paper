import ApiInterface
import ComposableArchitecture

extension Effect where Action == StoragePathFormReducer.Action {

    static func runSaveStoragePath(
        id: StoragePath.Id?,
        input: SaveStoragePathInput,
        server: Server
    ) -> Self {
        @Dependency(\.saveStoragePath.execute)
        var saveStoragePath

        return .run { send in
            await send(.binding(.set(\.isSaving, true)))
            let storagePath = try await saveStoragePath(id, input, server)
            await send(.delegate(.storagePathSaved(storagePath)), animation: .default)
            await send(.binding(.set(\.isSaving, false)))
        } catch: { error, send in
            await send(.error(error), animation: .snappy)
            await send(.binding(.set(\.isSaving, false)))
        }
        .cancellable(id: CancelID.saveStoragePath)
    }
}

private enum CancelID {
    case saveStoragePath
}
