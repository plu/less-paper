import ApiInterface
import ComposableArchitecture
import Foundation

extension Effect {

    static func runBulkEdit<Value: DocumentBulkEditGenericValue>(
        documents: Set<Document.Id>,
        id: Value.ID?,
        server: Server
    ) -> Self where Action == DocumentBulkEditGenericValueReducer<Value>.Action {
        @Dependency(\.bulkEditDocuments.execute)
        var bulkEditDocuments

        let input = BulkEditDocumentsInput(
            documents: Array(documents),
            method: Value.method(id: id)
        )

        return .run { send in
            try await bulkEditDocuments(input, server)
            await send(.delegate(.documentsUpdated))
        } catch: { error, send in
            await send(.error(error))
        }
        .cancellable(id: CancelID.bulkEdit)
    }

    static func runConfirmApply<Value: DocumentBulkEditGenericValue>(
        message: LocalizedStringResource
    ) -> Self where Action == DocumentBulkEditGenericValueReducer<Value>.Action {
        @Dependency(\.documentBulkEditConfirmation.present)
        var presentConfirmation

        return .run { send in
            guard await presentConfirmation(message) else {
                return
            }
            await send(.applyConfirmed)
        }
        .cancellable(id: CancelID.confirmApply)
    }

    static func runGetSelectionData<Value: DocumentBulkEditGenericValue>(
        documents: Set<Document.Id>,
        server: Server
    ) -> Self where Action == DocumentBulkEditGenericValueReducer<Value>.Action {
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
