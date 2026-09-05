import ApiInterface
import Components
import ComposableArchitecture
import Foundation
import Tagged

@Reducer
public struct TagRowReducer: Sendable {

    public enum Action: ViewAction {
        case delegate(Delegate)
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

    @ObservableState
    public struct State: Equatable, Identifiable {

        public var id: Tag.Id { tag.id }

        var isUpdating = false

        // Stored rather than computed from `server`: constructing a ServerPermissions reads two
        // files and arms two file watchers, and a computed property would do that on every render.
        var permissions: ServerPermissions

        let server: Server

        let tag: Tag

        init(
            isUpdating: Bool = false,
            server: Server,
            tag: Tag
        ) {
            self.isUpdating = isUpdating
            self.server = server
            self.tag = tag
            permissions = ServerPermissions(server: server)
        }
    }

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .view(viewAction):
                switch viewAction {
                case .editButtonTapped:
                    return .send(.delegate(.editTag))
                case .deleteButtonTapped:
                    return .runConfirmDelete(name: state.tag.name)
                }
            case .delegate:
                return .none
            }
        }
    }
}
