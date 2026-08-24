import ApiInterface
import Components
import ComposableArchitecture
import Dependencies
import IdentifiedCollections

extension Effect where Action == CustomFieldQueryAtomEditorReducer.Action {

    // A stored condition holds bare document ids; the capsule needs their titles. An id that does
    // not come back is a deleted document and renders as its id rather than disappearing.
    static func runResolveLinkedDocuments(_ state: CustomFieldQueryAtomEditorReducer.State) -> Self {
        @Dependency(\.getDocumentsByIds)
        var getDocumentsByIds

        let ids = state.linkedDocumentIds
        let server = state.server

        guard state.field?.dataType == .documentLink, !ids.isEmpty else {
            return .none
        }

        return .run { send in
            let documents = try await getDocumentsByIds.execute(.init(ids: ids), server)
            await send(.linkedDocumentsLoaded(IdentifiedArray(uniqueElements: documents)))
        } catch: { error, send in
            await send(.error(error))
        }
    }

    static func runDismiss() -> Self {
        .run { _ in
            @Dependency(\.dismiss)
            var dismiss

            await dismiss()
        }
    }
}
