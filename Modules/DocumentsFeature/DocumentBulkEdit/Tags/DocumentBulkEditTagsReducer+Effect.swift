import ApiInterface
import ComposableArchitecture
import Foundation

extension Effect where Action == DocumentBulkEditTagsReducer.Action {

    static func runBulkEdit(
        addTags: [Tag.Id],
        documents: Set<Document.Id>,
        removeTags: [Tag.Id],
        server: Server
    ) -> Self {
        @Dependency(\.bulkEditDocuments.execute)
        var bulkEditDocuments

        let input = BulkEditDocumentsInput(
            documents: Array(documents),
            method: .modifyTags(.init(addTags: addTags, removeTags: removeTags))
        )

        return .run { send in
            try await bulkEditDocuments(input, server)
            await send(.delegate(.documentsUpdated))
        } catch: { error, send in
            await send(.error(error))
        }
        .cancellable(id: CancelID.bulkEdit)
    }

    static func runConfirmApply(
        addTags: [Tag],
        documentCount: Int,
        removeTags: [Tag]
    ) -> Self {
        @Dependency(\.documentBulkEditConfirmation.presentTags)
        var presentConfirmation

        return .run { send in
            guard await presentConfirmation(addTags, documentCount, removeTags) else {
                return
            }
            await send(.applyConfirmed)
        }
        .cancellable(id: CancelID.confirmApply)
    }

    static func runGetSelectionData(
        documents: Set<Document.Id>,
        server: Server
    ) -> Self {
        @Dependency(\.getSelectionData.execute)
        var getSelectionData

        let input = GetSelectionDataInput(documents: Array(documents))

        return .run { send in
            await send(.selectionDataLoaded(try await getSelectionData(input, server)))
        } catch: { error, send in
            await send(.error(error))
        }
        .cancellable(id: CancelID.getSelectionData)
    }
}

private enum CancelID {
    case bulkEdit
    case confirmApply
    case getSelectionData
}
