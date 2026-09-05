import ApiInterface
import Components
import ComposableArchitecture
import Foundation
import Tagged

@Reducer
public struct CustomFieldRowReducer: Sendable {

    public enum Action: ViewAction {
        case delegate(Delegate)
        case view(View)

        public enum Delegate {
            case deleteCustomField
            case editCustomField
        }

        public enum View {
            case deleteButtonTapped
            case editButtonTapped
        }
    }

    @ObservableState
    public struct State: Equatable, Identifiable {

        public var id: CustomField.Id { customField.id }

        let customField: CustomField

        var isUpdating = false

        // Stored rather than computed from `server`: constructing a ServerPermissions reads two
        // files and arms two file watchers, and a computed property would do that on every render.
        var permissions: ServerPermissions

        var canEdit: Bool { permissions.can(.changeCustomfield) }

        var canDelete: Bool { permissions.can(.deleteCustomField) }

        let server: Server

        init(
            isUpdating: Bool = false,
            server: Server,
            customField: CustomField
        ) {
            self.isUpdating = isUpdating
            self.server = server
            self.customField = customField
            permissions = ServerPermissions(server: server)
        }
    }

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .view(viewAction):
                switch viewAction {
                case .editButtonTapped:
                    return .send(.delegate(.editCustomField))
                case .deleteButtonTapped:
                    return .runConfirmDelete(name: state.customField.name)
                }
            case .delegate:
                return .none
            }
        }
    }
}
