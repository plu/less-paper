import ApiInterface
import ComposableArchitecture
import Foundation
import IdentifiedCollections
import Tagged

@Reducer
public struct TrashListReducer: Reducer, Sendable {

    @ObservableState
    public struct State: Equatable {

        var documents: IdentifiedArrayOf<Document> = []

        var error: String?

        var isLoaded = false

        /// The documents currently being restored or deleted, so their rows can say so and cannot
        /// be asked twice.
        var isWorkingOn: Set<Document.Id> = []

        let server: Server

        public init(server: Server) {
            self.server = server
        }

        init(
            documents: IdentifiedArrayOf<Document> = [],
            isLoaded: Bool = false,
            server: Server
        ) {
            self.documents = documents
            self.isLoaded = isLoaded
            self.server = server
        }
    }

    public enum Action: ViewAction {
        case documentsLoaded(Result<[Document], Error>)
        case operationFinished(ids: Set<Document.Id>, Result<Void, Error>)
        case view(View)
        case working(Set<Document.Id>)

        public enum View: Equatable, Sendable {
            case deleteForeverButtonTapped(Document.Id)
            case emptyTrashButtonTapped
            case onAppear
            case onRefresh
            case restoreButtonTapped(Document.Id)
        }
    }

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .documentsLoaded(.success(documents)):
                state.documents = IdentifiedArray(uniqueElements: documents)
                state.error = nil
                state.isLoaded = true
                return .none
            case let .documentsLoaded(.failure(error)):
                state.error = error.localizedDescription
                state.isLoaded = true
                return .none
            case let .operationFinished(ids, .success):
                // Removed rather than reloaded: the row is gone either way, and reloading would
                // make a restore look slower than it was.
                state.isWorkingOn.subtract(ids)
                for id in ids {
                    state.documents.remove(id: id)
                }
                return .none
            case let .operationFinished(ids, .failure(error)):
                state.isWorkingOn.subtract(ids)
                state.error = error.localizedDescription
                return .runLoadTrash(server: state.server)
            case let .working(ids):
                state.isWorkingOn.formUnion(ids)
                return .none
            case let .view(viewAction):
                switch viewAction {
                case let .deleteForeverButtonTapped(id):
                    guard let title = state.documents[id: id]?.title else {
                        return .none
                    }
                    return .runDeleteForever(ids: [id], server: state.server, title: title)
                case .emptyTrashButtonTapped:
                    return .runEmptyTrash(ids: Set(state.documents.ids), server: state.server)
                case .onAppear, .onRefresh:
                    return .runLoadTrash(server: state.server)
                case let .restoreButtonTapped(id):
                    return .runRestore(ids: [id], server: state.server)
                }
            }
        }
    }

    public init() {}
}
