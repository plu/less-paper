import ApiInterface
import IdentifiedCollections

extension CustomFieldQueryAtomEditorReducer.State {
    static func testValue(
        atom: CustomFieldQuery.Atom = .init(field: 1, op: .exists, value: .bool(true)),
        fields: IdentifiedArrayOf<CustomField> = IdentifiedArray(uniqueElements: [CustomField].previewValue),
        isSelectingOptions: Bool = false,
        path: CustomFieldQuery.Path = [0],
        server: Server = .testValue()
    ) -> Self {
        .init(
            atom: atom,
            isSelectingOptions: isSelectingOptions,
            fields: fields,
            path: path,
            server: server
        )
    }
}
