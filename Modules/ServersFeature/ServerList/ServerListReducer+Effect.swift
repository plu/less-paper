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
}

private enum CancelID {
    case getCredentials
}
