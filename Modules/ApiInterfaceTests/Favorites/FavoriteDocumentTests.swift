@testable import ApiInterface

import Foundation
import Testing

@Suite
struct FavoriteDocumentTests {

    @Test
    func test_idIsTheDocumentId() {
        let favorite = FavoriteDocument.testValue(document: .testValue(id: 7))

        #expect(favorite.id == 7)
    }

    // Not the API coders: JSONEncoder.apiEncoder formats every Date as "yyyy-MM-dd", which would
    // truncate `storedAt` and — far worse — `document.modified`, the field the refresh gate
    // compares. Favorites is the first thing to persist a Document to disk, so it is the first to
    // need a lossless pair.
    @Test
    func test_roundTripsLosslesslyIncludingTimeOfDay() throws {
        let modified = Date(timeIntervalSince1970: 1_756_290_271)
        let favorite = FavoriteDocument.testValue(
            document: .testValue(modified: modified),
            storedAt: modified
        )

        let data = try JSONEncoder.favoritesEncoder.encode(favorite)
        let decoded = try JSONDecoder.favoritesDecoder.decode(FavoriteDocument.self, from: data)

        #expect(decoded == favorite)
        #expect(decoded.document.modified == modified)
    }
}
