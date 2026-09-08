@testable import DocumentsFeature

import ApiInterface
import Foundation
import Testing
import TestSupport

@Suite(
    .dependencies()
)
struct DocumentFormCustomFieldValuePromptValueTests {

    @Test
    func promptValue_boolean_rendersTrueOrFalse() {
        #expect(DocumentFormCustomFieldValue.boolean(true).promptValue == "true")
        #expect(DocumentFormCustomFieldValue.boolean(false).promptValue == "false")
    }

    @Test
    func promptValue_date_rendersTheFormattedDate() {
        let date = Date(timeIntervalSince1970: 1_787_529_600)
        // Not `DateFormatter.createdDate` directly: ApiInterface, Components and DocumentsFeature
        // each carry their own internal `createdDate` extension, and this file's imports make the
        // name ambiguous. Same format, built locally instead.
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        #expect(DocumentFormCustomFieldValue.date(date).promptValue == formatter.string(from: date))
    }

    @Test
    func promptValue_date_nilIsOmitted() {
        #expect(DocumentFormCustomFieldValue.date(nil).promptValue == nil)
    }

    @Test
    func promptValue_monetary_rendersCurrencyAndAmount() {
        #expect(
            DocumentFormCustomFieldValue.monetary(currency: "EUR", amount: "1234.50").promptValue
                == "EUR1234.50"
        )
    }

    @Test
    func promptValue_monetary_emptyAmountIsOmitted() {
        #expect(DocumentFormCustomFieldValue.monetary(currency: "EUR", amount: "").promptValue == nil)
    }

    @Test
    func promptValue_number_rendersTheText() {
        #expect(DocumentFormCustomFieldValue.number("7").promptValue == "7")
    }

    @Test
    func promptValue_number_emptyIsOmitted() {
        #expect(DocumentFormCustomFieldValue.number("").promptValue == nil)
    }

    @Test
    func promptValue_text_rendersTheText() {
        #expect(DocumentFormCustomFieldValue.text("Ref").promptValue == "Ref")
    }

    @Test
    func promptValue_text_emptyIsOmitted() {
        #expect(DocumentFormCustomFieldValue.text("").promptValue == nil)
    }

    // ids rather than labels: sending them would cost tokens without telling the model anything
    // about the document.
    @Test
    func promptValue_documentLink_isAlwaysOmitted() {
        #expect(DocumentFormCustomFieldValue.documentLink([]).promptValue == nil)
        #expect(DocumentFormCustomFieldValue.documentLink([2, 3]).promptValue == nil)
    }

    @Test
    func promptValue_select_isAlwaysOmitted() {
        #expect(DocumentFormCustomFieldValue.select(nil).promptValue == nil)
        #expect(DocumentFormCustomFieldValue.select("abc").promptValue == nil)
    }

    @Test
    func promptValue_unsupported_isAlwaysOmitted() {
        #expect(DocumentFormCustomFieldValue.unsupported(.null).promptValue == nil)
        #expect(
            DocumentFormCustomFieldValue.unsupported(.object(["nested": .number(1)])).promptValue
                == nil
        )
    }
}
