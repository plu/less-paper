@testable import ApiInterface

import Foundation
import Testing
import TestSupport

@Suite(
    .dependencies()
)
struct DocumentCustomFieldTests {

    @Test(
        arguments: [
            ("string", "\"Reference 42\"", JSONValue.string("Reference 42")),
            ("date", "\"2026-08-24\"", .string("2026-08-24")),
            ("monetary", "\"EUR1234.50\"", .string("EUR1234.50")),
            ("select", "\"G1btwlUUPsE9K3ta\"", .string("G1btwlUUPsE9K3ta")),
            ("boolean", "true", .bool(true)),
            ("integer", "7", .number(7)),
            ("float", "1.5", .number(1.5)),
            ("documentLink", "[2, 3]", .array([.number(2), .number(3)])),
            ("empty", "null", .null),
        ]
    )
    func decoding_readsEveryValueShape(name: String, json: String, expected: JSONValue) throws {
        let field = try JSONDecoder.apiDecoder.decode(
            DocumentCustomField.self,
            from: Data("{\"field\": 21, \"value\": \(json)}".utf8)
        )

        #expect(field.field == 21)
        #expect(field.value == expected)
    }

    // A value shape no known data type uses. It has to survive the round trip untouched, because a
    // save replaces the document's whole list and would otherwise blank fields of a type this app
    // does not yet know.
    @Test
    func encoding_roundTripsAnUnrecognisedValueShape() throws {
        let json = Data("{\"field\":21,\"value\":{\"nested\":[1,\"two\"]}}".utf8)

        let field = try JSONDecoder.apiDecoder.decode(DocumentCustomField.self, from: json)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let encoded = try encoder.encode(field)

        #expect(String(decoding: encoded, as: UTF8.self) == "{\"field\":21,\"value\":{\"nested\":[1,\"two\"]}}")
    }
}
