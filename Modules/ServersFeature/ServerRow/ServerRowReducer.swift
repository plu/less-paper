import ApiInterface
import Components
import ComposableArchitecture
import Foundation
import SwiftSharing

@Reducer
public struct ServerRowReducer: Sendable {

    public enum Action: ViewAction {
        case delegate(Delegate)
        case destination(PresentationAction<Destination.Action>)
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

    @Reducer
    public enum Destination {
        case confirmation(ConfirmationDialogState<Confirmation>)

        public enum Confirmation: Equatable {
            case deleteButtonTapped
        }
    }

    @ObservableState
    public struct State: Equatable, Identifiable {
        public var id: String { server.id }

        @Presents
        var destination: Destination.State?

        var isSelecting = false

        let server: Server
    }

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .destination(.presented(.confirmation(.deleteButtonTapped))):
                state.destination = nil
                return .run { send in
                    await send(.delegate(.deleteServer), animation: .default)
                }
            case let .view(viewAction):
                switch viewAction {
                case .editButtonTapped:
                    return .send(.delegate(.editServer))
                case .deleteButtonTapped:
                    state.destination = .confirmation(.confirmDelete(name: state.server.alias))
                    return .none
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
            case .delegate, .destination:
                return .none
            }
        }
        .ifLet(\.$destination, action: \.destination)
    }
}

extension ServerRowReducer.Destination.State: Equatable {}
