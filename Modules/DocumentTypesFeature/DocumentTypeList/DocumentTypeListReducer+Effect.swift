import ApiInterface
import ComposableArchitecture

extension Effect where Action == DocumentTypeListReducer.Action {

    static func runDeleteDocumentType(
        id: DocumentType.Id,
        server: Server
    ) -> Self {
        @Dependency(\.deleteDocumentType.execute)
        var deleteDocumentType

        return .run { send in
            await send(.isUpdating(id: id, isUpdating: true))
            try await deleteDocumentType(id, server)
            await send(.documentTypeDeleted(id), animation: .default)
        } catch: { error, send in
            await send(.error(error))
            await send(.isUpdating(id: id, isUpdating: false))
        }
        .cancellable(id: CancelID.deleteDocumentType)
    }

    static func runGetDocumentTypes(server: Server) -> Self {
        @Dependency(\.getDocumentTypes.execute)
        var getDocumentTypes

        return .run { send in
            try await send(.getDocumentTypesResult(getDocumentTypes(server)), animation: .default)
            await send(.set(\.isLoaded, true))
        } catch: { error, send in
            await send(.error(error))
            await send(.set(\.isLoaded, true))
        }
        .cancellable(id: CancelID.getDocumentTypes)
    }
}

private enum CancelID {
    case deleteDocumentType
    case getDocumentTypes
}
