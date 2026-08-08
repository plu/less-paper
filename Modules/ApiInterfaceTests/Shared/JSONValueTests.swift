@testable import ApiInterface

import CustomDump
import Foundation
import Testing

@Suite
struct JSONValueTests {

    @Test
    func decode_encode_roundTrip() async throws {
        let json = """
        {
          "array": [1, "two", true, null],
          "bool": false,
          "nested": {
            "number": 3.5
          },
          "null": null,
          "number": 42,
          "string": "hello"
        }
        """

        let decoded = try JSONDecoder().decode([String: JSONValue].self, from: #require(json.data(using: .utf8)))
        let data = try JSONEncoder().encode(decoded)
        let redecoded = try JSONDecoder().decode([String: JSONValue].self, from: data)

        expectNoDifference(redecoded, decoded)
        expectNoDifference(decoded["string"], .string("hello"))
        expectNoDifference(decoded["number"], .number(42))
        expectNoDifference(decoded["bool"], .bool(false))
        expectNoDifference(decoded["null"], .null)
        expectNoDifference(decoded["array"], .array([.number(1), .string("two"), .bool(true), .null]))
        expectNoDifference(decoded["nested"], .object(["number": .number(3.5)]))
    }
}
