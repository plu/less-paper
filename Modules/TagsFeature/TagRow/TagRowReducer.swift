import ApiInterface
import Components
import ComposableArchitecture
import Foundation
import Tagged

@Reducer
public struct TagRowReducer: Sendable {

    public enum Action: ViewAction {
        case delegate(Delegate)
        case destination(PresentationAction<Destination.Action>)
        case view(View)

        public enum Delegate {
            case deleteTag
            case editTag
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

        public var id: Tag.Id { tag.id }

        @Presents
        var destination: Destination.State?

        var isUpdating = false

        let server: Server

        let tag: Tag
    }

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .destination(.presented(.confirmation(.deleteButtonTapped))):
                state.destination = nil
                return .send(.delegate(.deleteTag))
            case let .view(viewAction):
                switch viewAction {
                case .editButtonTapped:
                    return .send(.delegate(.editTag))
                case .deleteButtonTapped:
                    state.destination = .confirmation(.confirmDelete(name: state.tag.name))
                    return .none
                }
            case .delegate, .destination:
                return .none
            }
        }
        .ifLet(\.$destination, action: \.destination)
    }
}

extension TagRowReducer.Destination.State: Equatable {}
