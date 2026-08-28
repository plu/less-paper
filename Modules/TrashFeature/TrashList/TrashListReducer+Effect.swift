import ApiInterface
import ComposableArchitecture

extension Effect where Action == TrashListReducer.Action {

    static func runLoadTrash(server: Server) -> Self {
        @Dependency(\.getTrash.execute)
        var getTrash

        return .run { send in
            await send(.documentsLoaded(.success(try await getTrash(server).results)))
        } catch: { error, send in
            await send(.documentsLoaded(.failure(error)))
        }
        .cancellable(id: CancelID.loadTrash, cancelInFlight: true)
    }

    /// Asks first, then marks the rows, so a slow server cannot be asked twice.
    static func runDeleteForever(ids: Set<Document.Id>, server: Server, title: String) -> Self {
        @Dependency(\.emptyTrash.execute)
        var emptyTrash

        @Dependency(\.trashConfirmation)
        var trashConfirmation

        return .run { send in
            guard await trashConfirmation.confirmDeleteForever(title) else {
                return
            }
            await send(.working(ids))
            try await emptyTrash(Array(ids), server)
            await send(.operationFinished(ids: ids, .success(())))
        } catch: { error, send in
            await send(.operationFinished(ids: ids, .failure(error)))
        }
    }

    static func runEmptyTrash(ids: Set<Document.Id>, server: Server) -> Self {
        @Dependency(\.emptyTrash.execute)
        var emptyTrash

        @Dependency(\.trashConfirmation)
        var trashConfirmation

        return .run { send in
            guard await trashConfirmation.confirmEmptyTrash() else {
                return
            }
            await send(.working(ids))
            // An empty id list is the server's own way of saying everything, but the ids are sent
            // explicitly: the list on screen is what the user was looking at when they agreed.
            try await emptyTrash(Array(ids), server)
            await send(.operationFinished(ids: ids, .success(())))
        } catch: { error, send in
            await send(.operationFinished(ids: ids, .failure(error)))
        }
    }

    static func runRestore(ids: Set<Document.Id>, server: Server) -> Self {
        @Dependency(\.restoreDocuments.execute)
        var restoreDocuments

        return .run { send in
            await send(.working(ids))
            try await restoreDocuments(Array(ids), server)
            await send(.operationFinished(ids: ids, .success(())))
        } catch: { error, send in
            await send(.operationFinished(ids: ids, .failure(error)))
        }
    }
}

private enum CancelID {
    case loadTrash
}
