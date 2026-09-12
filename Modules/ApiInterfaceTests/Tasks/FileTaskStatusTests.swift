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

    // A cancelled import is shown under Failed rather than dropped. The paperless web UI hides
    // revoked tasks entirely, and a row that exists on the server but nowhere in the app is the
    // worse of the two answers.
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
