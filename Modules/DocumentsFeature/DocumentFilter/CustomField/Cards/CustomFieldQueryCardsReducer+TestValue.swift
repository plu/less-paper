import ApiInterface
import IdentifiedCollections

extension CustomFieldQueryCardsReducer.State {
    static func testValue(
        editor: Editor? = nil,
        fields: IdentifiedArrayOf<CustomField> = IdentifiedArray(uniqueElements: [CustomField].previewValue),
        query: CustomFieldQuery? = nil
    ) -> Self {
        .init(
            editor: editor,
            fields: fields,
            query: query
        )
    }
}
