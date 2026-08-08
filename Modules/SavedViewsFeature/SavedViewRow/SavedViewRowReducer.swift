import ApiInterface
import Components
import ComposableArchitecture
import Foundation
import Tagged

@Reducer
public struct SavedViewRowReducer: Sendable {

    public enum Action: ViewAction {
        case delegate(Delegate)
        case destination(PresentationAction<Destination.Action>)
        case view(View)

        public enum Delegate {
            case deleteSavedView
            case editSavedView
        }

        public enum View {
            case deleteButtonTapped
            case editButtonTapped
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

        public var id: SavedView.Id { savedView.id }

        let savedView: SavedView

        @Presents
        var destination: Destination.State?

        var isUpdating = false

        let server: Server
    }

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .destination(.presented(.confirmation(.deleteButtonTapped))):
                state.destination = nil
                return .send(.delegate(.deleteSavedView))
            case let .view(viewAction):
                switch viewAction {
                case .editButtonTapped:
                    return .send(.delegate(.editSavedView))
                case .deleteButtonTapped:
                    state.destination = .confirmation(.confirmDelete(name: state.savedView.name))
                    return .none
                }
            case .delegate, .destination:
                return .none
            }
        }
        .ifLet(\.$destination, action: \.destination)
    }
}

extension SavedViewRowReducer.Destination.State: Equatable {}
