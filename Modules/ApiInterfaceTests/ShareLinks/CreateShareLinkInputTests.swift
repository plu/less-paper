@testable import ApiInterface

import Foundation
import Testing
import TestSupport

@Suite(
    .testDependencies()
)
struct CreateShareLinkInputTests {

    @Test
    func encode_never() throws {
        let input = CreateShareLinkInput.testValue(document: 42, expiration: nil, fileVersion: .original)

        let object = try encoded(input)

        // Present as null rather than omitted: paperless reads a missing key as "use the default".
        #expect(object.keys.contains("expiration"))
        #expect(object["expiration"] is NSNull)
        #expect(object["file_version"] as? String == "original")
        #expect(object["document"] as? Int == 42)
    }

    @Test
    func encode_withExpiration() throws {
        let input = CreateShareLinkInput.testValue(
            expiration: Date(timeIntervalSince1970: 1_800_000_000),
            fileVersion: .archive
        )

        let object = try encoded(input)

        #expect(object["file_version"] as? String == "archive")
        #expect(object["expiration"] as? String == "2027-01-15T08:00:00Z")
    }
}

private func encoded(_ input: CreateShareLinkInput) throws -> [String: Any] {
    let data = try JSONEncoder.apiEncoder.encode(input)
    return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
}
