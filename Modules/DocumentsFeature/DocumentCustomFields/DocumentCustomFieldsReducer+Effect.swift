import ApiInterface
import ComposableArchitecture

extension Effect where Action == DocumentCustomFieldsReducer.Action {

    static func runResolveLinkedDocuments(
        _ state: DocumentCustomFieldsReducer.State
    ) -> Self {
        let ids = state.rows.flatMap { row -> [Document.Id] in
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
            await send(.linkedDocuments(IdentifiedArray(uniqueElements: documents)))
        } catch: { _, _ in
            // Deliberately silent, as the edit form is: these titles decorate a value the reader
            // can already see, and the capsule falls back to the id.
        }
    }
}
