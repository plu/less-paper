import ApiInterface
import Components
import ComposableArchitecture
import Foundation
import SwiftSharing

@Reducer
public struct PermissionsFormReducer: Sendable {

    public enum Action: BindableAction, ViewAction {
        case binding(BindingAction<State>)
        case delegate(Delegate)
        case error(Error)
        case getPermissionsResult(GetPermissionsOutput)
        case view(View)

        @CasePathable
        public enum Delegate {
            case permissionsUpdated(PermissionsFormUpdate)
        }

        public enum View {
            case onAppear
        }
    }

    @ObservableState
    public struct State: Equatable {

        let server: Server

        let type: PermissionsType?

        var isLoading = false

        var options: PermissionsFormOptions

        var selection: PermissionsFormSelection

        @Shared
        var currentUser: User?

        @Shared
        var groups: IdentifiedArrayOf<Group>

        @Shared
        var users: IdentifiedArrayOf<User>

        public init(
            server: Server,
            type: PermissionsType?
        ) {
            self.init(
                options: .init(),
                selection: .init(),
                server: server,
                type: type
            )
        }

        init(
            options: PermissionsFormOptions,
            selection: PermissionsFormSelection,
            server: Server,
            type: PermissionsType?
        ) {
            self.options = options
            self.selection = selection
            self.server = server
            self.type = type
            self._currentUser = Shared(wrappedValue: nil, .currentUser(server))
            self._groups = Shared(wrappedValue: .init(), .groups(server))
            self._users = Shared(wrappedValue: .init(), .users(server))
        }
    }

    public var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding(\.selection):
                let apiValue = state.selection.apiValue
                return .send(.delegate(.permissionsUpdated(.init(
                    owner: .init(value: apiValue.owner),
                    permissions: apiValue.permissions
                ))))
            case let .error(error):
                return .toast(error)
            case let .getPermissionsResult(permissions):
                state.update(permissions: permissions)
                return .none
            case let .view(viewAction):
                switch viewAction {
                case .onAppear:
                    guard state.options.groups.isEmpty, state.options.users.isEmpty else {
                        return .none
                    }
                    return .runGetData(
                        server: state.server,
                        type: state.type
                    )
                }
            case .binding, .delegate:
                return .none
            }
        }
    }

    public init() {}
}

private extension PermissionsFormReducer.State {

    mutating func update(permissions: GetPermissionsOutput) {
        options = .init(
            groups: groups,
            users: users
        )
        selection = .init(
            change: .init(
                groups: Set(permissions.permissions?.change.groups.compactMap { groups[id: $0] } ?? []),
                users: Set(permissions.permissions?.change.users.compactMap { users[id: $0] } ?? [])
            ),
            owner: users[id: permissions.owner ?? 0],
            view: .init(
                groups: Set(permissions.permissions?.view.groups.compactMap { groups[id: $0] } ?? []),
                users: Set(permissions.permissions?.view.users.compactMap { users[id: $0] } ?? [])
            )
        )
        if type == nil && selection.owner == nil {
            selection.owner = currentUser
        }
    }
}
