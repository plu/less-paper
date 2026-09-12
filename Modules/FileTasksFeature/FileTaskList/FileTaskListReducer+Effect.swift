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
        .cancellable(id: CancelID.loadFileTasks, cancelInFlight: true)
    }

    static func runLoadMoreFileTasks(server: Server, status: FileTaskStatus, page: Int) -> Self {
        @Dependency(\.getFileTasks.execute)
        var getFileTasks

        return .run { send in
            await send(.moreTasksLoaded(.success(try await getFileTasks(server, status, page))))
        } catch: { error, send in
            await send(.moreTasksLoaded(.failure(error)))
        }
        .cancellable(id: CancelID.loadMoreFileTasks, cancelInFlight: true)
    }

    static func runDismiss(id: FileTask.Id, server: Server) -> Self {
        @Dependency(\.acknowledgeFileTask.execute)
        var acknowledgeFileTask

        return .run { send in
            try await acknowledgeFileTask(id, server)
            await send(.dismissFinished(id: id, .success(())))
        } catch: { error, send in
            await send(.dismissFinished(id: id, .failure(error)))
        }
    }
}

private enum CancelID {
    case loadFileTasks
    case loadMoreFileTasks
}
