@testable import ApiInterface

import Foundation
import Testing
import TestSupport

@Suite(
    .testDependencies()
)
struct OfflineDocumentTests {

    @Test
    func test_idIsTheDocumentId() {
        let offlineDocument = OfflineDocument.testValue(document: .testValue(id: 7))

        #expect(offlineDocument.id == 7)
    }

    // Not the API coders: JSONEncoder.apiEncoder formats every Date as "yyyy-MM-dd", which would
    // truncate `storedAt` and — far worse — `document.modified`, the field the refresh gate
    // compares. Offline is the first thing to persist a Document to disk, so it is the first to
    // need a lossless pair.
    @Test
    func test_roundTripsLosslesslyIncludingTimeOfDay() throws {
        let modified = Date(timeIntervalSince1970: 1_756_290_271)
        let offlineDocument = OfflineDocument.testValue(
            document: .testValue(modified: modified),
            storedAt: modified
        )

        let data = try JSONEncoder.offlineEncoder.encode(offlineDocument)
        let decoded = try JSONDecoder.offlineDecoder.decode(OfflineDocument.self, from: data)

        #expect(decoded == offlineDocument)
        #expect(decoded.document.modified == modified)
    }
}
