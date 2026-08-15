import ApiInterface
import Dependencies
import Foundation

func refreshStatistics(server: Server) async {
    @Dependency(\.getStatistics.execute)
    var getStatistics

    do {
        _ = try await getStatistics(server)
    } catch {}
}
