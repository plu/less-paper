import ApiInterface
import Dependencies
import Foundation

/**
 * Re-reads the server's statistics so the cached counts — and with them the Inbox tab badge —
 * reflect a mutation that just succeeded.
 *
 * Call this after any operation that can change how many documents sit in the inbox: creating,
 * updating, bulk editing or deleting documents.
 *
 * Failures are deliberately swallowed. The mutation itself has already succeeded by this point, so
 * surfacing a refresh error would report a failure that did not happen and that the user cannot act
 * on. A failed refresh leaves the counts showing their previous value until something refreshes
 * them again.
 *
 * - Parameter server: The server whose statistics to re-read.
 */
func refreshStatistics(server: Server) async {
    @Dependency(\.getStatistics.execute)
    var getStatistics

    do {
        _ = try await getStatistics(server)
    } catch {}
}
