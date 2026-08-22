import ApiInterface
import Components
import ComposableArchitecture
import Foundation
import SwiftSharing

@Reducer
public struct ServerRowReducer: Sendable {

    public enum Action: ViewAction {
        case delegate(Delegate)
        case serverSelected
        case view(View)

        public enum Delegate {
            case deleteServer
            case editServer
        }

        public enum View {
            case deleteButtonTapped
            case editButtonTapped
            case serverTapped
        }
    }

    @ObservableState
    public struct State: Equatable, Identifiable {
        public var id: String { server.id }

        var isSelecting = false

        let server: Server
    }

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .view(viewAction):
                switch viewAction {
                case .editButtonTapped:
                    return .send(.delegate(.editServer))
                case .deleteButtonTapped:
                    return .runConfirmDelete(name: state.server.alias)
                case .serverTapped:
                    guard !state.isSelecting else {
                        return .none
                    }
                    state.isSelecting = true
                    return .runSelectServer(server: state.server)
                }
            case .serverSelected:
                state.isSelecting = false
                return .none
            case .delegate:
                return .none
            }
        }
    }
}
