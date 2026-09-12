import ApiInterface
import ComposableArchitecture

extension Effect where Action == FileTaskListReducer.Action {

    static func runLoadFileTasks(server: Server, status: FileTaskStatus, page: Int) -> Self {
        @Dependency(\.getFileTasks.execute)
        var getFileTasks

        return .run { send in
            await send(.tasksLoaded(.success(try await getFileTasks(server, status, page))))
        } catch: { error, send in
            await send(.tasksLoaded(.failure(error)))
        }
        .cancellable(id: CancelID.fileTasks, cancelInFlight: true)
    }

    static func runLoadMoreFileTasks(server: Server, status: FileTaskStatus, page: Int) -> Self {
        @Dependency(\.getFileTasks.execute)
        var getFileTasks

        return .run { send in
            await send(.moreTasksLoaded(.success(try await getFileTasks(server, status, page))))
        } catch: { error, send in
            await send(.moreTasksLoaded(.failure(error)))
        }
        // The initial load's id, so restarting the list - a segment switch, a refresh - drops a
        // next page still in flight. It would otherwise resolve into the new segment's list and
        // overwrite its nextPage with the old one's. Not cancelInFlight, the other way round: an
        // initial load already running is the fresher request of the two, and a row appearing must
        // not cancel it.
        .cancellable(id: CancelID.fileTasks)
    }

    static func runDismiss(id: FileTask.Id, server: Server) -> Self {
        @Dependency(\.acknowledgeFileTask.execute)
        var acknowledgeFileTask

        return .run { send in
            try await acknowledgeFileTask([id], server)
            await send(.dismissFinished(id: id, .success(())), animation: .default)
        } catch: { error, send in
            await send(.dismissFinished(id: id, .failure(error)))
        }
    }

    static func runConfirmDismissAll(ids: [FileTask.Id], server: Server) -> Self {
        @Dependency(\.fileTaskDismissAllConfirmation.present)
        var presentConfirmation

        return .run { send in
            guard await presentConfirmation(ids.count) else {
                return
            }
            await send(.dismissAllConfirmed(ids: ids))
        }
        .cancellable(id: CancelID.confirmDismissAll)
    }

    static func runDismissAll(ids: [FileTask.Id], server: Server) -> Self {
        @Dependency(\.acknowledgeFileTask.execute)
        var acknowledgeFileTask

        return .run { send in
            try await acknowledgeFileTask(ids, server)
            await send(.dismissAllFinished(ids: ids, .success(())), animation: .default)
        } catch: { error, send in
            await send(.dismissAllFinished(ids: ids, .failure(error)))
        }
    }
}

private enum CancelID {
    case confirmDismissAll
    case fileTasks
}
