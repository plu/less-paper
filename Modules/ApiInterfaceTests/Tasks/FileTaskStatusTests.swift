@testable import ApiInterface

import Foundation
import Testing

@Suite
struct FileTaskStatusTests {

    @Test
    func initApiValue_readsBothSpellings() {
        #expect(FileTaskStatus(apiValue: "SUCCESS") == .complete)
        #expect(FileTaskStatus(apiValue: "success") == .complete)
        #expect(FileTaskStatus(apiValue: "FAILURE") == .failed)
        #expect(FileTaskStatus(apiValue: "failure") == .failed)
        #expect(FileTaskStatus(apiValue: "STARTED") == .started)
        #expect(FileTaskStatus(apiValue: "started") == .started)
        #expect(FileTaskStatus(apiValue: "PENDING") == .queued)
        #expect(FileTaskStatus(apiValue: "pending") == .queued)
    }

    // A cancelled import reads as a failure rather than as an unknown state. This only reaches the
    // Failed list on a v9 server, where the whole array is fetched and filtered in memory: v10 asks
    // for `status=failure` (see apiQueryValue) so a revoked task is never fetched at all, and the
    // badge misses it for the same reason. Mapping it here is still the right answer - it is what
    // makes the v9 path show the row, and it costs nothing on v10.
    @Test
    func initApiValue_mapsRevokedToFailed() {
        #expect(FileTaskStatus(apiValue: "REVOKED") == .failed)
        #expect(FileTaskStatus(apiValue: "revoked") == .failed)
    }

    @Test
    func initApiValue_isNilForAnythingElse() {
        #expect(FileTaskStatus(apiValue: "RETRY") == nil)
        #expect(FileTaskStatus(apiValue: "") == nil)
    }

    // Paperless will add task states. A value this app has never heard of must not throw: it reads
    // as queued, the one bucket that raises no alarm and promises no outcome.
    @Test
    func decode_fallsBackToQueued() throws {
        let json = #""not_a_real_status""#
        let status = try JSONDecoder.apiDecoder.decode(
            FileTaskStatus.self,
            from: #require(json.data(using: .utf8))
        )

        #expect(status == .queued)
    }

    // The middle branch of init(from:)'s fallback chain: a wire spelling is not a rawValue, so a
    // cached or decoded `"success"` has to come back through init(apiValue:) rather than as .queued.
    @Test
    func decode_readsAWireSpelling() throws {
        let json = #""success""#
        let status = try JSONDecoder.apiDecoder.decode(
            FileTaskStatus.self,
            from: #require(json.data(using: .utf8))
        )

        #expect(status == .complete)
    }

    @Test
    func decode_roundTripsAKnownValue() throws {
        let json = #""failed""#
        let status = try JSONDecoder.apiDecoder.decode(
            FileTaskStatus.self,
            from: #require(json.data(using: .utf8))
        )

        #expect(status == .failed)
    }
}
