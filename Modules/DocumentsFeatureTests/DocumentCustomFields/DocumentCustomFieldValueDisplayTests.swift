@testable import DocumentsFeature

import ApiInterface
import CustomDump
import Foundation
import Testing
import TestSupport

@Suite(
    .dependencies()
)
struct DocumentCustomFieldValueDisplayTests {

    @Test
    func booleanReadsAsYesOrNo() async throws {
        let field = CustomField.testValue(dataType: .boolean, id: 1, name: "Paid")

        expectNoDifference(DocumentFormCustomFieldValue.boolean(true).displayValue(field: field), "Yes")
        expectNoDifference(DocumentFormCustomFieldValue.boolean(false).displayValue(field: field), "No")
    }

    @Test
    func selectShowsTheOptionLabelNotItsId() async throws {
        let field = CustomField.testValue(
            dataType: .select,
            extraData: .init(selectOptions: [.init(id: "abc", label: "Approved")]),
            id: 2,
            name: "Status"
        )

        expectNoDifference(DocumentFormCustomFieldValue.select("abc").displayValue(field: field), "Approved")
    }

    // A definition can lose an option while a document still stores its id. Showing the id says
    // something true; a blank would imply the field was never set.
    @Test
    func selectFallsBackToTheIdWhenTheOptionIsGone() async throws {
        let field = CustomField.testValue(
            dataType: .select,
            extraData: .init(selectOptions: []),
            id: 2,
            name: "Status"
        )

        expectNoDifference(DocumentFormCustomFieldValue.select("abc").displayValue(field: field), "abc")
    }

    @Test
    func monetaryJoinsCurrencyAndAmount() async throws {
        let field = CustomField.testValue(dataType: .monetary, id: 3, name: "Total")

        expectNoDifference(
            DocumentFormCustomFieldValue.monetary(currency: "EUR", amount: "1234.50").displayValue(field: field),
            "EUR 1234.50"
        )
    }

    @Test
    func emptyValuesReadAsNilSoTheirRowIsDropped() async throws {
        let text = CustomField.testValue(dataType: .string, id: 4, name: "Note")
        let date = CustomField.testValue(dataType: .date, id: 5, name: "Due")

        #expect(DocumentFormCustomFieldValue.text("").displayValue(field: text) == nil)
        #expect(DocumentFormCustomFieldValue.date(nil).displayValue(field: date) == nil)
        #expect(DocumentFormCustomFieldValue.number("").displayValue(field: text) == nil)
    }

    // Links are capsules, not a string, so the row renders them itself.
    @Test
    func documentLinkHasNoStringForm() async throws {
        let field = CustomField.testValue(dataType: .documentLink, id: 6, name: "Related")

        #expect(DocumentFormCustomFieldValue.documentLink([2]).displayValue(field: field) == nil)
    }
}
