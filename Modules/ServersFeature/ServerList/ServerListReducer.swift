import ApiInterface
import Components
import ComposableArchitecture
import Foundation
import SwiftSharing

@Reducer
public struct ServerListReducer: Sendable {

    public enum Action: ViewAction {
        case destination(PresentationAction<Destination.Action>)
        case getCredentialsResult(Credentials?, Server)
        case servers(IdentifiedActionOf<ServerRowReducer>)
        case view(View)

        public enum View {
            case createServerButtonTapped
        }
    }

    @Reducer
    public enum Destination {
        case serverForm(ServerFormReducer)
    }

    @ObservableState
    public struct State: Equatable {

        @Presents
        var destination: Destination.State?

        var servers: IdentifiedArrayOf<ServerRowReducer.State> = []

        public init(
            destination: Destination.State? = nil
        ) {
            @Shared(.servers)
            var storedServers: IdentifiedArrayOf<Server>

            self.destination = destination
            self.servers = IdentifiedArray(
                uniqueElements: storedServers.map { ServerRowReducer.State(server: $0) }
            )
            self.sort()
        }
    }

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .destination(.presented(.serverForm(.delegate(.serverSaved(server))))):
                state.destination = nil
                state.servers.updateOrAppend(ServerRowReducer.State(server: server))
                state.sync()
                return .none
            case let .getCredentialsResult(credentials, server):
                state.destination = .serverForm(ServerFormReducer.State(input: .init(
                    alias: server.alias,
                    headers: server.headers,
                    id: server.id,
                    password: credentials?.password ?? "",
                    url: server.url,
                    username: server.username
                )))
                return .none
            case let .servers(.element(id: id, action: .delegate(delegateAction))):
                switch delegateAction {
                case .deleteServer:
                    state.servers.remove(id: id)
                    state.sync()
                    return .none
                case .editServer:
                    return .runGetCredentials(
                        server: state.servers[id: id]?.server
                    )
                }
            case let .view(viewAction):
                switch viewAction {
                case .createServerButtonTapped:
                    state.destination = .serverForm(ServerFormReducer.State(input: .empty))
                    return .none
                }
            case .destination, .servers:
                return .none
            }
        }
        .forEach(\.servers, action: \.servers) { ServerRowReducer() }
        .ifLet(\.$destination, action: \.destination)
    }

    public init() {}
}

extension ServerListReducer.Destination.State: Equatable {}

extension ServerListReducer.State {

    mutating func sort() {
        servers.sort {
            $0.server.alias.compare(
                $1.server.alias,
                options: [
                    .caseInsensitive,
                    .numeric,
                    .forcedOrdering
                ]
            ) == .orderedAscending
        }
    }

    mutating func sync() {
        sort()

        @Shared(.selectedServer)
        var selectedServer: Server?

        @Shared(.servers)
        var storedServers: IdentifiedArrayOf<Server>

        $storedServers.withLock { $0 = IdentifiedArray(uniqueElements: self.servers.map(\.server)) }
        $selectedServer.withLock {
            if [0, 1].contains(storedServers.count) {
                $0 = storedServers.first
            }
        }
    }
}
