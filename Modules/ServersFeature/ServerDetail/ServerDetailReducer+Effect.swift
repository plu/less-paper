import ApiInterface
import ComposableArchitecture

extension Effect where Action == ServerDetailReducer.Action {

    static func runRefresh(server: Server) -> Self {
        @Dependency(\.updateCache.execute)
        var updateCache

        @Dependency(\.getStatistics.execute)
        var getStatistics

        return .run { send in
            try await updateCache(server)
            let statistics = try await getStatistics(server)
            await send(.statisticsLoaded(statistics))
        } catch: { _, send in
            await send(.refreshFailed)
        }
        .cancellable(id: CancelID.refresh, cancelInFlight: true)
    }
}

private enum CancelID {
    case refresh
}
