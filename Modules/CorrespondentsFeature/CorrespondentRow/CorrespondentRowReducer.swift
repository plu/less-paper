import ApiInterface
import Components
import ComposableArchitecture
import Foundation
import Tagged

@Reducer
public struct CorrespondentRowReducer: Sendable {

    public enum Action: ViewAction {
        case delegate(Delegate)
        case view(View)

        public enum Delegate {
            case deleteCorrespondent
            case editCorrespondent
        }

        public enum View {
            case deleteButtonTapped
            case editButtonTapped
        }
    }

    @ObservableState
    public struct State: Equatable, Identifiable {

        public var id: Correspondent.Id { correspondent.id }

        let correspondent: Correspondent

        var isUpdating = false

        let server: Server
    }

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .view(viewAction):
                switch viewAction {
                case .editButtonTapped:
                    return .send(.delegate(.editCorrespondent))
                case .deleteButtonTapped:
                    return .runConfirmDelete(name: state.correspondent.name)
                }
            case .delegate:
                return .none
            }
        }
    }
}
