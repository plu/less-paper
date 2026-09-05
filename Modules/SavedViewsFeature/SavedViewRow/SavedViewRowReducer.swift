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

        // Stored rather than computed from `server`: constructing a ServerPermissions reads two
        // files and arms two file watchers, and a computed property would do that on every render.
        var permissions: ServerPermissions

        var canEdit: Bool { permissions.can(.changeSavedView) }

        var canDelete: Bool { permissions.can(.deleteSavedView) }

        let server: Server

        init(
            isUpdating: Bool = false,
            server: Server,
            savedView: SavedView
        ) {
            self.isUpdating = isUpdating
            self.server = server
            self.savedView = savedView
            permissions = ServerPermissions(server: server)
        }
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
