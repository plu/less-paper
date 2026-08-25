@testable import ApiInterface

import Foundation
import Testing
import TestSupport

@Suite(
    .dependencies()
)
struct UpdateDocumentInputTests {

    @Test
    func encoding_writesCustomFieldsUnderTheSnakeCaseKey() throws {
        let input = UpdateDocumentInput.testValue(customFields: [
            .testValue(field: 21, value: .string("EUR1234.50")),
            .testValue(field: 17, value: .null),
        ])

        let json = try String(decoding: JSONEncoder.apiEncoder.encode(input), as: UTF8.self)

        #expect(json.contains("\"custom_fields\""))
        #expect(json.contains("\"value\" : \"EUR1234.50\""))
        #expect(json.contains("\"value\" : null"))
    }

    // The server replaces the document's whole list with whatever is sent, so an empty array is how
    // every field is detached at once.
    @Test
    func encoding_writesAnEmptyArrayRatherThanOmittingTheKey() throws {
        let input = UpdateDocumentInput.testValue(customFields: [])

        let json = try String(decoding: JSONEncoder.apiEncoder.encode(input), as: UTF8.self)

        #expect(json.contains("\"custom_fields\" : ["))
    }
}
