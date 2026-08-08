import ApiInterface
import ComposableArchitecture
import SwiftSharing

extension Effect where Action == ServerRowReducer.Action {
    static func runSelectServer(
        server: Server
    ) -> Self {
        @Shared(.selectedServer)
        var selectedServer: Server?

        $selectedServer.withLock { $0 = server }

        return .none
    }
}
