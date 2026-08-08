import ApiInterface
import ComposableArchitecture
import Foundation

extension Effect where Action == DocumentFormReducer.Action {

    static func runDismiss() -> Self {
        .run { _ in
            @Dependency(\.dismiss)
            var dismiss

            await dismiss()
        }
    }

    static func runGetNextArchiveSerialNumber(server: Server) -> Self {
        .run { send in
            @Dependency(\.getNextArchiveSerialNumber.execute)
            var getNextArchiveSerialNumber
            await send(.set(\.isLoadingNextArchiveSerialNumber, true))
            try await send(.nextArchiveSerialNumber(getNextArchiveSerialNumber(server)))
            await send(.set(\.isLoadingNextArchiveSerialNumber, false))
        } catch: { _, send in
            await send(.set(\.isLoadingNextArchiveSerialNumber, false))
        }
    }

    static func runUpdateDocument(id: Document.Id, input: DocumentFormInput, server: Server) -> Self {
        .run { send in
            @Dependency(\.updateDocument.execute)
            var updateDocument
            await send(.set(\.isUpdating, true))
            try await send(.updateResult(.success(updateDocument(id, input.apiValue, server))))
            await send(.set(\.isUpdating, false))
        } catch: { error, send in
            await send(.updateResult(.failure(error)))
            await send(.set(\.isUpdating, false))
        }
    }
}

private enum CancelID {
    case saveDocument
}
