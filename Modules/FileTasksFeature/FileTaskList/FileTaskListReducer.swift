import ApiInterface
import Components
import ComposableArchitecture
import Foundation
import IdentifiedCollections
import SwiftSharing

@Reducer
public struct FileTaskListReducer: Reducer, Sendable {

    @ObservableState
    public struct State: Equatable {

        var segment: FileTaskStatus

        var tasks: IdentifiedArrayOf<FileTask> = []

        var nextPage: Int?

        var isLoaded = false

        var isLoadingMore = false

        // The rows being dismissed, so they can say so and cannot be asked twice.
        var isDismissing: Set<FileTask.Id> = []

        // Stored rather than computed: constructing a ServerPermissions reads two files and arms two
        // file watchers, which is not something to do on every render.
        var permissions: ServerPermissions

        @Shared
        var failedCount: Int

        let server: Server

        var canDismiss: Bool { permissions.can(.changePaperlessTask) }

        public init(server: Server) {
            // Read through a local: every stored property has to be initialised before any of them
            // can be read back, so `_failedCount.wrappedValue` here would not compile.
            let failedCount = Shared(.failedFileTaskCount(server))

            self.server = server
            permissions = ServerPermissions(server: server)
            _failedCount = failedCount
            // Opening onto an empty Failed list is a worse first impression than opening onto the
            // imports that did work.
            segment = failedCount.wrappedValue > 0 ? .failed : .complete
        }

        init(
            segment: FileTaskStatus = .complete,
            tasks: IdentifiedArrayOf<FileTask> = [],
            isLoaded: Bool = false,
            server: Server
        ) {
            self.isLoaded = isLoaded
            self.segment = segment
            self.server = server
            self.tasks = tasks
            permissions = ServerPermissions(server: server)
            _failedCount = Shared(.failedFileTaskCount(server))
        }
    }

    public enum Action: BindableAction, ViewAction {
        case binding(BindingAction<State>)
        case delegate(Delegate)
        case dismissFinished(id: FileTask.Id, Result<Void, Error>)
        case moreTasksLoaded(Result<FileTaskPage, Error>)
        case tasksLoaded(Result<FileTaskPage, Error>)
        case view(View)

        @CasePathable
        public enum Delegate: Equatable, Sendable {
            case close
            case openDocument(Document.Id)
        }

        public enum View: Equatable, Sendable {
            case closeButtonTapped
            case dismissButtonTapped(FileTask.Id)
            case onAppear
            case onRefresh
            case onRowAppear(FileTask)
            case rowTapped(FileTask)
        }
    }

    public var body: some ReducerOf<Self> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .binding(\.segment):
                state.isLoaded = false
                state.nextPage = nil
                state.tasks = []
                return .runLoadFileTasks(server: state.server, status: state.segment, page: 1)
            case .binding, .delegate:
                return .none
            case let .tasksLoaded(.success(page)):
                state.isLoaded = true
                state.nextPage = page.nextPage
                state.tasks = IdentifiedArray(uniqueElements: page.tasks)
                return .none
            case let .tasksLoaded(.failure(error)):
                state.isLoaded = true
                return .toast(error)
            case let .moreTasksLoaded(.success(page)):
                state.isLoadingMore = false
                state.nextPage = page.nextPage
                for task in page.tasks {
                    state.tasks.updateOrAppend(task)
                }
                return .none
            case let .moreTasksLoaded(.failure(error)):
                state.isLoadingMore = false
                return .toast(error)
            case let .dismissFinished(id, .success):
                // Removed rather than reloaded: the row is gone either way, and a reload would make
                // the dismiss look slower than it was. The failure count is not touched here either
                // - AcknowledgeFileTaskUseCase re-reads it from the server itself.
                state.isDismissing.remove(id)
                state.tasks.remove(id: id)
                return .none
            case let .dismissFinished(id, .failure(error)):
                state.isDismissing.remove(id)
                return .toast(error)
            case let .view(viewAction):
                switch viewAction {
                case .closeButtonTapped:
                    return .send(.delegate(.close))
                case let .dismissButtonTapped(id):
                    guard !state.isDismissing.contains(id) else {
                        return .none
                    }
                    state.isDismissing.insert(id)
                    return .runDismiss(id: id, server: state.server)
                case .onAppear, .onRefresh:
                    return .runLoadFileTasks(server: state.server, status: state.segment, page: 1)
                case let .onRowAppear(task):
                    guard let nextPage = state.nextPage,
                          !state.isLoadingMore,
                          state.tasks.last?.id == task.id
                    else {
                        return .none
                    }
                    state.isLoadingMore = true
                    return .runLoadMoreFileTasks(
                        server: state.server,
                        status: state.segment,
                        page: nextPage
                    )
                case let .rowTapped(task):
                    guard let documentId = task.documentId else {
                        return .none
                    }
                    return .send(.delegate(.openDocument(documentId)))
                }
            }
        }
    }

    public init() {}
}
