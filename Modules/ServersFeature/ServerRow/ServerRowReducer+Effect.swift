import ApiInterface
import ComposableArchitecture
import SwiftSharing

extension Effect where Action == ServerRowReducer.Action {
    static func runSelectServer(
        server: Server
    ) -> Self {
        @Dependency(\.updateCache.execute)
        var updateCache

        return .run { send in
            try await updateCache(server)
            await select(server)
            await send(.serverSelected, animation: .default)
        } catch: { _, send in
            await select(server)
            await send(.serverSelected, animation: .default)
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
    case selectServer
}
