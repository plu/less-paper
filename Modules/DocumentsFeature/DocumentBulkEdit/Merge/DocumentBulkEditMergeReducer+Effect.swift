import ApiInterface
import ComposableArchitecture
import Foundation

extension Effect where Action == DocumentBulkEditMergeReducer.Action {

    static func runConfirmMerge(
        deleteOriginals: Bool,
        documentCount: Int
    ) -> Self {
        @Dependency(\.documentBulkEditConfirmation.presentMerge)
        var presentConfirmation

        return .run { send in
            guard await presentConfirmation(deleteOriginals, documentCount) else {
                return
            }
            await send(.mergeConfirmed)
        }
        .cancellable(id: CancelID.confirmMerge)
    }

    static func runDismiss() -> Self {
        .run { _ in
            @Dependency(\.dismiss)
            var dismiss

            await dismiss()
        }
    }

    // One request, not the chunked loop `DocumentBulkEditTitleReducer` uses: the server applies
    // `ordering` per request, so concatenating chunks would interleave their orders and hand the
    // user a page order that is not the one the list showed.
    static func runGetDocumentsByIds(
        ids: Set<Document.Id>,
        server: Server,
        sort: DocumentFilterInput.SortFilter
    ) -> Self {
        @Dependency(\.getDocumentsByIds.execute)
        var getDocumentsByIds

        let input = GetDocumentsByIdsInput(
            ids: ids.sorted(),
            sortDirection: sort.direction,
            sortField: sort.field
        )

        return .run { send in
            await send(.documentsLoaded(try await getDocumentsByIds(input, server)))
        } catch: { error, send in
            await send(.error(error))
        }
        .cancellable(id: CancelID.getDocumentsByIds)
    }

    static func runMerge(
        deleteOriginals: Bool,
        documents: [Document.Id],
        server: Server
    ) -> Self {
        @Dependency(\.bulkEditDocuments.execute)
        var bulkEditDocuments

        let input = BulkEditDocumentsInput(
            documents: documents,
            method: .merge(.init(
                archiveFallback: true,
                deleteOriginals: deleteOriginals
            ))
        )

        return .run { send in
            try await bulkEditDocuments(input, server)
            await send(.delegate(.documentsMerged))
        } catch: { error, send in
            await send(.error(error))
        }
        .cancellable(id: CancelID.merge)
    }
}

private enum CancelID {
    case confirmMerge
    case getDocumentsByIds
    case merge
}
