import ApiInterface
import Components
import ComposableArchitecture
import Foundation

@Reducer
public struct StoragePathListReducer: Sendable {

    public enum Action: BindableAction, ViewAction {
        case binding(BindingAction<State>)
        case destination(PresentationAction<Destination.Action>)
        case error(Error)
        case isUpdating(id: StoragePath.Id, isUpdating: Bool)
        case getStoragePathsResult([StoragePath])
        case storagePathDeleted(StoragePath.Id)
        case storagePaths(IdentifiedActionOf<StoragePathRowReducer>)
        case view(View)

        public enum View {
            case createStoragePathButtonTapped
            case onAppear
            case onRefresh
        }
    }

    @Reducer
    public enum Destination {
        case storagePathForm(StoragePathFormReducer)
    }

    @ObservableState
    public struct State: Equatable {

        let server: Server

        var searchText = ""

        var storagePaths: IdentifiedArrayOf<StoragePathRowReducer.State>

        // Local only: the list is already in memory, so filtering it needs no request and works
        // offline. localizedCaseInsensitiveContains rather than lowercased().contains, matching the
        // filter sheets - the latter is wrong for locales whose case folding is not one-to-one.
        var visibleStoragePaths: IdentifiedArrayOf<StoragePathRowReducer.State> {
            guard !searchText.isEmpty else {
                return storagePaths
            }
            return storagePaths.filter {
                $0.storagePath.name.localizedCaseInsensitiveContains(searchText)
                    || $0.storagePath.path.localizedCaseInsensitiveContains(searchText)
            }
        }

        @Presents
        var destination: Destination.State?

        var isLoaded: Bool

        public init(
            storagePaths: IdentifiedArrayOf<StoragePathRowReducer.State> = [],
            destination: Destination.State? = nil,
            isLoaded: Bool = false,
            server: Server
        ) {
            self.storagePaths = storagePaths
            self.destination = destination
            self.isLoaded = isLoaded
            self.server = server
        }
    }

    public var body: some ReducerOf<Self> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case let .destination(.presented(.storagePathForm(.delegate(.storagePathSaved(storagePath))))):
                state.destination = nil
                state.storagePaths.updateOrAppend(StoragePathRowReducer.State(storagePath: storagePath, server: state.server))
                return .none
            case let .error(error):
                return .toast(error)
            case let .getStoragePathsResult(storagePaths):
                state.storagePaths = IdentifiedArray(
                    uniqueElements: storagePaths.map {
                        StoragePathRowReducer.State(
                            storagePath: $0,
                            server: state.server
                        )
                    }
                )
                return .none
            case let .isUpdating(id: id, isUpdating: isUpdating):
                state.storagePaths[id: id]?.isUpdating = isUpdating
                return .none
            case let .storagePathDeleted(id):
                state.storagePaths.remove(id: id)
                return .none
            case let .storagePaths(.element(id: id, action: .delegate(delegateAction))):
                switch delegateAction {
                case .deleteStoragePath:
                    return .runDeleteStoragePath(
                        id: id,
                        server: state.server
                    )
                case .editStoragePath:
                    state.destination = .storagePathForm(StoragePathFormReducer.State(
                        storagePath: state.storagePaths[id: id]?.storagePath,
                        server: state.server
                    ))
                    return .none
                }
            case let .view(viewAction):
                switch viewAction {
                case .createStoragePathButtonTapped:
                    state.destination = .storagePathForm(StoragePathFormReducer.State(
                        server: state.server
                    ))
                    return .none
                case .onAppear, .onRefresh:
                    return .runGetStoragePaths(server: state.server)
                }
            case .binding, .destination, .storagePaths:
                return .none
            }
        }
        .forEach(\.storagePaths, action: \.storagePaths) { StoragePathRowReducer() }
        .ifLet(\.$destination, action: \.destination)

        Reduce { state, _ in
            state.storagePaths.sort {
                $0.storagePath.name.compare(
                    $1.storagePath.name,
                    options: [
                        .caseInsensitive,
                        .numeric,
                        .forcedOrdering
                    ]
                ) == .orderedAscending
            }
            return .none
        }
    }

    public init() {}
}

extension StoragePathListReducer.Destination.State: Equatable {}
