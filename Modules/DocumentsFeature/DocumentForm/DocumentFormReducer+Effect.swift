import ApiInterface
import ComposableArchitecture
import Foundation
import IdentifiedCollections

extension Effect where Action == DocumentFormReducer.Action {

    static func runDismiss() -> Self {
        .run { _ in
            @Dependency(\.dismiss)
            var dismiss

            await dismiss()
        }
    }

    static func runGetDocument(id: Document.Id, server: Server) -> Self {
        .run { send in
            @Dependency(\.getDocument.execute)
            var getDocument
            try await send(.documentResult(.success(getDocument(id, server))))
        } catch: { error, send in
            await send(.documentResult(.failure(error)))
        }
    }

    // A stored documentlink value holds bare ids; the capsules need titles. An id that does not
    // come back is a deleted document and renders as its id rather than disappearing.
    static func runResolveLinkedCustomFieldDocuments(
        _ state: DocumentFormReducer.State
    ) -> Self {
        let ids = state.input.customFields.flatMap { row -> [Document.Id] in
            guard case let .documentLink(ids) = row.value else {
                return []
            }
            return ids
        }

        guard !ids.isEmpty else {
            return .none
        }

        let server = state.server

        return .run { send in
            @Dependency(\.getDocumentsByIds.execute)
            var getDocumentsByIds

            let documents = try await getDocumentsByIds(.init(ids: ids), server)
            await send(.linkedCustomFieldDocuments(IdentifiedArray(uniqueElements: documents)))
        } catch: { _, _ in
            // Deliberately silent. These titles are decoration on a value the user can still see
            // and edit; a toast for a failed lookup would interrupt an edit over nothing.
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

    static func runUpdateDocument(
        content: String?,
        id: Document.Id,
        input: DocumentFormInput,
        server: Server
    ) -> Self {
        .run { send in
            @Dependency(\.updateDocument.execute)
            var updateDocument
            await send(.set(\.isUpdating, true))
            try await send(.updateResult(.success(updateDocument(id, input.apiValue(content: content, server: server), server))))
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
