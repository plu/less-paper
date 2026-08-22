import ApiInterface
import Components
import ComposableArchitecture
import SwiftSharing

extension Effect where Action == ServerRowReducer.Action {
    static func runConfirmDelete(name: String) -> Self {
        @Dependency(\.deleteConfirmation.present)
        var presentConfirmation

        return .run { send in
            guard await presentConfirmation(.deleteServer, name) else {
                return
            }
            await send(.delegate(.deleteServer), animation: .default)
        }
        .cancellable(id: CancelID.confirmDelete)
    }

    static func runSelectServer(
        server: Server
    ) -> Self {
        @Dependency(\.updateCache.execute)
        var updateCache

        // Clearing the row's flag has to happen before the selection is written. Writing
        // `selectedServer` rebuilds `MainReducer.State`, which empties the settings navigation
        // stack this row lives in — anything sent afterwards arrives at a missing element.
        return .run { send in
            try await updateCache(server)
            await send(.serverSelected, animation: .default)
            await select(server)
        } catch: { _, send in
            await send(.serverSelected, animation: .default)
            await select(server)
        }
        .cancellable(
            id: CancelID.selectServer,
            cancelInFlight: true
        )
    }

    private static func select(_ server: Server) async {
        @Shared(.selectedServer)
        var selectedServer: Server?

        $selectedServer.withLock { $0 = server }
    }
}

private enum CancelID {
    case confirmDelete
    case selectServer
}
