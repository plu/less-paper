import ApiInterface
import Components
import ComposableArchitecture
import Foundation
import Tagged

@Reducer
public struct StoragePathRowReducer: Sendable {

    public enum Action: ViewAction {
        case delegate(Delegate)
        case view(View)

        public enum Delegate {
            case deleteStoragePath
            case editStoragePath
        }

        public enum View {
            case deleteButtonTapped
            case editButtonTapped
        }
    }

    @ObservableState
    public struct State: Equatable, Identifiable {

        public var id: StoragePath.Id { storagePath.id }

        let storagePath: StoragePath

        var isUpdating = false

        let server: Server
    }

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .view(viewAction):
                switch viewAction {
                case .editButtonTapped:
                    return .send(.delegate(.editStoragePath))
                case .deleteButtonTapped:
                    return .runConfirmDelete(name: state.storagePath.name)
                }
            case .delegate:
                return .none
            }
        }
    }
}
