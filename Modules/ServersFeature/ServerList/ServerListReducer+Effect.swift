import ApiInterface
import ComposableArchitecture
import Foundation
import SwiftSharing

extension Effect where Action == ServerListReducer.Action {
    static func runGetCredentials(
        server: Server?
    ) -> Self {
        guard let server else {
            return .none
        }

        @Dependency(\.getCredentials.execute)
        var getCredentials

        return .run { send in
            try await send(.getCredentialsResult(getCredentials(server), server))
        } catch: { _, send in
            await send(.getCredentialsResult(nil, server))
        }
        .cancellable(id: CancelID.getCredentials)
    }

    static func runServersObserver() -> Self {
        @Shared(.servers)
        var servers: IdentifiedArrayOf<Server>

        return .publisher {
            $servers
                .publisher
                .receive(on: RunLoop.main)
                .removeDuplicates()
                .map(Action.serversChanged)
        }
        .cancellable(
            id: CancelID.observeServersChanges,
            cancelInFlight: true
        )
    }
}

private enum CancelID {
    case getCredentials
    case observeServersChanges
}
