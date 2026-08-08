import ApiInterface
import ComposableArchitecture

extension Effect where Action == DocumentTypeFormReducer.Action {

    static func runSaveDocumentType(
        id: DocumentType.Id?,
        input: SaveDocumentTypeInput,
        server: Server
    ) -> Self {
        @Dependency(\.saveDocumentType.execute)
        var saveDocumentType

        return .run { send in
            await send(.binding(.set(\.isSaving, true)))
            let documentType = try await saveDocumentType(id, input, server)
            await send(.delegate(.documentTypeSaved(documentType)), animation: .default)
            await send(.binding(.set(\.isSaving, false)))
        } catch: { error, send in
            await send(.error(error), animation: .snappy)
            await send(.binding(.set(\.isSaving, false)))
        }
        .cancellable(id: CancelID.saveDocumentType)
    }
}

private enum CancelID {
    case saveDocumentType
}
