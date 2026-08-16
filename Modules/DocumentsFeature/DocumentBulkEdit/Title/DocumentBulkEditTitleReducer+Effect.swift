import ApiInterface
import ComposableArchitecture
import Foundation

extension Effect where Action == DocumentBulkEditTitleReducer.Action {

    static func runConfirmApply(documentCount: Int) -> Self {
        @Dependency(\.documentBulkEditConfirmation.presentTitle)
        var presentConfirmation

        return .run { send in
            guard await presentConfirmation(documentCount) else {
                return
            }
            await send(.applyConfirmed)
        }
        .cancellable(id: CancelID.confirmApply)
    }

    static func runDismiss() -> Self {
        .run { _ in
            @Dependency(\.dismiss)
            var dismiss

            await dismiss()
        }
    }

    static func runGetDocumentsByIds(
        ids: Set<Document.Id>,
        server: Server
    ) -> Self {
        @Dependency(\.getDocumentsByIds.execute)
        var getDocumentsByIds

        let chunks = ids.sorted().chunked(into: loadChunkSize)

        return .run { send in
            for chunk in chunks {
                await send(.documentsLoaded(try await getDocumentsByIds(.init(ids: chunk), server)))
            }
            await send(.documentsLoadFinished)
        } catch: { error, send in
            await send(.error(error))
        }
        .cancellable(id: CancelID.getDocumentsByIds)
    }

    static func runUpdateTitles(
        previews: [DocumentBulkEditTitleReducer.Preview],
        server: Server
    ) -> Self {
        @Dependency(\.updateDocument.execute)
        var updateDocument

        let update: @Sendable (DocumentBulkEditTitleReducer.Preview) async -> (Document.Id, Bool) = { preview in
            do {
                _ = try await updateDocument(preview.id, preview.updateInput, server)
                return (preview.id, true)
            } catch {
                return (preview.id, false)
            }
        }

        return .run { send in
            var completed = 0
            var failed = Set<Document.Id>()
            var next = 0

            // Refilled as each request finishes rather than started all at once: a selection can
            // run to thousands after "select all matching", and there is no bulk endpoint to
            // collapse them into one call.
            await withTaskGroup(of: (Document.Id, Bool).self) { group in
                while next < min(maximumRequestsInFlight, previews.count) {
                    group.addTask { [preview = previews[next]] in await update(preview) }
                    next += 1
                }

                while let (id, isSuccess) = await group.next() {
                    completed += 1
                    if !isSuccess {
                        failed.insert(id)
                    }
                    await send(.progress(completed: completed))

                    if next < previews.count {
                        group.addTask { [preview = previews[next]] in await update(preview) }
                        next += 1
                    }
                }
            }

            await send(.saved(failed: failed))
        }
        .cancellable(id: CancelID.updateTitles)
    }
}

private let loadChunkSize = 100

private let maximumRequestsInFlight = 4

private enum CancelID {
    case confirmApply
    case getDocumentsByIds
    case updateTitles
}
