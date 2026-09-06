import ApiInterface
import ComposableArchitecture

extension Effect where Action == ServerDetailReducer.Action {

    static func runRefresh(server: Server) -> Self {
        @Dependency(\.updateCache.execute)
        var updateCache

        @Dependency(\.getStatistics.execute)
        var getStatistics

        @Dependency(\.negotiateApiVersion.execute)
        var negotiateApiVersion

        return .run { send in
            // Negotiated here, not only when a server is added: that is the only other caller, so
            // a server configured before this screen existed - which is every server anyone has -
            // would show its versions as Unknown forever. Tolerated separately because the versions
            // are the least of what this screen shows, and losing them must not cost the counts.
            _ = try? await negotiateApiVersion(server)
            try await updateCache(server)
            let statistics = try await getStatistics(server)
            await send(.statisticsLoaded(statistics))
        } catch: { _, send in
            await send(.refreshFailed)
        }
        .cancellable(id: CancelID.refresh, cancelInFlight: true)
    }

    static func runLoadAuthMode(server: Server) -> Self {
        @Dependency(\.authenticationProvider.getToken)
        var getToken

        return .run { send in
            let token = try? await getToken(server)
            await send(.authModeLoaded(token != nil))
        }
        .cancellable(id: CancelID.loadAuthMode, cancelInFlight: true)
    }
}

private enum CancelID {
    case loadAuthMode
    case refresh
}
