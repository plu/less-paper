@testable import DocumentsFeature

import ApiInterface
import Foundation
import IdentifiedCollections
import Testing
import TestSupport

@Suite(
    .dependencies {
        $0.apiCache.customField = { id, _ in
            [CustomField].previewValue.first { $0.id == id }
        }
    }
)
struct DocumentFormInputCustomFieldsTests {

    @Test
    func init_seedsTheDocumentsFieldsInOrder() {
        let input = DocumentFormInput(
            document: .testValue(customFields: [
                .testValue(field: 2, value: .string("2026-08-24")),
                .testValue(field: 1, value: .string("Ref")),
            ]),
            server: .testValue()
        )

        #expect(input.customFields.ids == [2, 1])
        #expect(input.customFields[id: 1]?.value == .text("Ref"))
    }

    // A definition the cache does not know cannot be rendered or converted, and guessing a type
    // would corrupt the value on save.
    @Test
    func init_dropsAFieldWithNoKnownDefinition() {
        let input = DocumentFormInput(
            document: .testValue(customFields: [.testValue(field: 999, value: .string("Ref"))]),
            server: .testValue()
        )

        #expect(input.customFields.isEmpty)
    }

    @Test
    func apiValue_writesTheFieldsBackInOrder() {
        let input = DocumentFormInput(
            document: .testValue(customFields: [
                .testValue(field: 1, value: .string("Ref")),
                .testValue(field: 3, value: .bool(true)),
            ]),
            server: .testValue()
        )

        #expect(input.apiValue(content: nil, server: .testValue()).customFields == [
            .testValue(field: 1, value: .string("Ref")),
            .testValue(field: 3, value: .bool(true)),
        ])
    }

    // The whole design rests on this: both sides of `isModified` derive from the same document, so
    // an untouched sheet must compare equal for every data type.
    @Test
    func roundTrip_leavesAnUntouchedDocumentUnmodified() {
        let document = Document.testValue(customFields: [
            .testValue(field: 1, value: .string("Ref")),
            .testValue(field: 2, value: .string("2026-08-24")),
            .testValue(field: 3, value: .bool(true)),
            .testValue(field: 4, value: .string("EUR1234.50")),
            .testValue(field: 5, value: .string("aqgT3m4XZw8aw3Ou")),
        ])
        let server = Server.testValue()

        let onOpen = DocumentFormInput(document: document, server: server)
        let baseline = DocumentFormInput(document: document, server: server)

        #expect(onOpen == baseline)
        #expect(onOpen.apiValue(content: nil, server: server).customFields == document.customFields)
    }

    @Test
    func hasInvalidCustomField_isTrueForAnUnparseableNumber() {
        var input = DocumentFormInput(document: .testValue(), server: .testValue())
        input.customFields = [.init(id: 1, value: .number("abc"))]

        #expect(input.hasInvalidCustomField)
    }
}
