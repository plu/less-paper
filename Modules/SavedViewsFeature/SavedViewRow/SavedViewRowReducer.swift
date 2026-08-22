import ApiInterface
import Components
import ComposableArchitecture
import Foundation
import Tagged

@Reducer
public struct SavedViewRowReducer: Sendable {

    public enum Action: ViewAction {
        case delegate(Delegate)
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

    @ObservableState
    public struct State: Equatable, Identifiable {

        public var id: SavedView.Id { savedView.id }

        let savedView: SavedView

        var isUpdating = false

        let server: Server
    }

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .view(viewAction):
                switch viewAction {
                case .editButtonTapped:
                    return .send(.delegate(.editSavedView))
                case .deleteButtonTapped:
                    return .runConfirmDelete(name: state.savedView.name)
                }
            case .delegate:
                return .none
            }
        }
    }
}
