import ApiInterface
import Dependencies
import Foundation

// Shaped like refreshStatistics, down to swallowing the error: the use case does the writing, so a
// failed refresh simply leaves the last known count in place. A badge reading 0 because the request
// failed is a lie.
func refreshFailedFileTaskCount(server: Server) async {
    @Dependency(\.getFailedFileTaskCount.execute)
    var getFailedFileTaskCount

    do {
        _ = try await getFailedFileTaskCount(server)
    } catch {}
}
