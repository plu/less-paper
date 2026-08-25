@testable import DocumentsFeature

import ApiInterface
import Foundation
import Testing
import TestSupport

@Suite(
    .dependencies()
)
struct DocumentFormCustomFieldValueTests {

    @Test
    func init_readsEachDataType() throws {
        #expect(
            DocumentFormCustomFieldValue(field: .testValue(dataType: .string), json: .string("Ref"))
                == .text("Ref")
        )
        #expect(
            DocumentFormCustomFieldValue(field: .testValue(dataType: .boolean), json: .bool(true))
                == .boolean(true)
        )
        #expect(
            DocumentFormCustomFieldValue(field: .testValue(dataType: .integer), json: .number(7))
                == .number("7")
        )
        #expect(
            DocumentFormCustomFieldValue(field: .testValue(dataType: .float), json: .number(1.5))
                == .number("1.5")
        )
        #expect(
            DocumentFormCustomFieldValue(field: .testValue(dataType: .select), json: .string("abc"))
                == .select("abc")
        )
        #expect(
            DocumentFormCustomFieldValue(
                field: .testValue(dataType: .documentLink),
                json: .array([.number(2), .number(3)])
            ) == .documentLink([2, 3])
        )
    }

    // An integer arrives as a Double. Rendering 7.0 as "7.0" in a field the user then saves would
    // send a float where the server expects an int.
    @Test
    func init_rendersAnIntegerWithoutADecimalPoint() {
        #expect(
            DocumentFormCustomFieldValue(field: .testValue(dataType: .integer), json: .number(7))
                == .number("7")
        )
    }

    @Test
    func init_readsADate() throws {
        let value = DocumentFormCustomFieldValue(
            field: .testValue(dataType: .date),
            json: .string("2026-08-24")
        )

        #expect(value == .date(Date(timeIntervalSince1970: 1_787_529_600)))
    }

    @Test
    func init_splitsAMonetaryValueIntoCurrencyAndAmount() {
        #expect(
            DocumentFormCustomFieldValue(
                field: .testValue(dataType: .monetary),
                json: .string("EUR1234.50")
            ) == .monetary(currency: "EUR", amount: "1234.50")
        )
    }

    // Another client may have stored a bare amount. The field's default currency fills the gap.
    @Test
    func init_fallsBackToTheFieldsDefaultCurrency() {
        #expect(
            DocumentFormCustomFieldValue(
                field: .testValue(dataType: .monetary, extraData: .init(defaultCurrency: "CHF")),
                json: .string("1234.50")
            ) == .monetary(currency: "CHF", amount: "1234.50")
        )
    }

    @Test
    func init_keepsAnUnknownDataTypeVerbatim() {
        let json = JSONValue.object(["nested": .number(1)])

        #expect(
            DocumentFormCustomFieldValue(field: .testValue(dataType: .unknown), json: json)
                == .unsupported(json)
        )
    }

    @Test
    func json_writesEachDataType() {
        #expect(DocumentFormCustomFieldValue.text("Ref")
            .json(field: .testValue(dataType: .string)) == .string("Ref"))
        #expect(DocumentFormCustomFieldValue.boolean(true)
            .json(field: .testValue(dataType: .boolean)) == .bool(true))
        #expect(DocumentFormCustomFieldValue.number("7")
            .json(field: .testValue(dataType: .integer)) == .number(7))
        #expect(DocumentFormCustomFieldValue.number("1.5")
            .json(field: .testValue(dataType: .float)) == .number(1.5))
        #expect(DocumentFormCustomFieldValue.select("abc")
            .json(field: .testValue(dataType: .select)) == .string("abc"))
        #expect(DocumentFormCustomFieldValue.documentLink([2, 3])
            .json(field: .testValue(dataType: .documentLink)) == .array([.number(2), .number(3)]))
        #expect(DocumentFormCustomFieldValue.date(Date(timeIntervalSince1970: 1_787_529_600))
            .json(field: .testValue(dataType: .date)) == .string("2026-08-24"))
    }

    // Verified against the server: "1234" alone is accepted, but "EUR1234" is a 400. A currency
    // code obliges the decimals, and this design always sends a code.
    @Test(
        arguments: [
            ("1234", "EUR1234.00"),
            ("1234.5", "EUR1234.50"),
            ("1234.50", "EUR1234.50"),
            ("-5", "EUR-5.00"),
        ]
    )
    func json_normalisesAMonetaryAmountToTwoDecimals(amount: String, expected: String) {
        let value = DocumentFormCustomFieldValue.monetary(currency: "EUR", amount: amount)

        #expect(value.json(field: .testValue(dataType: .monetary)) == .string(expected))
    }

    @Test(
        arguments: [
            DocumentFormCustomFieldValue.text(""),
            .number(""),
            .date(nil),
            .select(nil),
            .documentLink([]),
            .monetary(currency: "EUR", amount: ""),
        ]
    )
    func json_writesNullForAnEmptyEditor(value: DocumentFormCustomFieldValue) {
        #expect(value.json(field: .testValue(dataType: .string)) == .null)
    }

    @Test
    func json_keepsAnUnsupportedValueVerbatim() {
        let json = JSONValue.object(["nested": .number(1)])

        #expect(DocumentFormCustomFieldValue.unsupported(json)
            .json(field: .testValue(dataType: .unknown)) == json)
    }

    // The property this whole design leans on: reading a value and writing it back unchanged must
    // produce the same JSON, or every document would open already "modified".
    @Test(
        arguments: [
            (CustomFieldDataType.string, JSONValue.string("Ref")),
            (.longText, .string("line one\nline two")),
            (.url, .string("https://example.com")),
            (.date, .string("2026-08-24")),
            (.boolean, .bool(true)),
            (.integer, .number(7)),
            (.float, .number(1.5)),
            (.monetary, .string("EUR1234.50")),
            (.select, .string("G1btwlUUPsE9K3ta")),
            (.documentLink, .array([.number(2), .number(3)])),
            (.unknown, .object(["nested": .number(1)])),
            (.string, .null),
        ]
    )
    func roundTrip_isStable(dataType: CustomFieldDataType, json: JSONValue) {
        let field = CustomField.testValue(dataType: dataType)

        #expect(DocumentFormCustomFieldValue(field: field, json: json).json(field: field) == json)
    }

    @Test(
        arguments: ["abc", "1.234", "1,5", "-", "1..2"]
    )
    func validationError_rejectsAnUnparseableNumber(amount: String) {
        #expect(DocumentFormCustomFieldValue.number(amount).validationError != nil)
        #expect(DocumentFormCustomFieldValue.monetary(currency: "EUR", amount: amount)
            .validationError != nil)
    }

    @Test(
        arguments: ["", "0", "7", "1.5", "1.50", "-5.00"]
    )
    func validationError_acceptsAWellFormedNumber(amount: String) {
        #expect(DocumentFormCustomFieldValue.number(amount).validationError == nil)
    }
}
