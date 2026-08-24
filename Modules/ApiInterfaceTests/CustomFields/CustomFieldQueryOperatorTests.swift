@testable import ApiInterface

import Foundation
import Testing

@Suite
struct CustomFieldQueryOperatorTests {

    @Test
    func operatorsForStringExcludeArithmetic() {
        #expect(CustomFieldQueryOperator.operators(for: .string) == [.exists, .isnull, .exact, .icontains])
    }

    @Test
    func operatorsForUrlMatchString() {
        #expect(CustomFieldQueryOperator.operators(for: .url) == [.exists, .isnull, .exact, .icontains])
    }

    @Test
    func operatorsForLongTextOmitExact() {
        #expect(CustomFieldQueryOperator.operators(for: .longText) == [.exists, .isnull, .icontains])
    }

    @Test
    func operatorsForDateAreDeduplicated() {
        #expect(CustomFieldQueryOperator.operators(for: .date) == [.exists, .isnull, .exact, .gte, .lte])
    }

    @Test
    func operatorsForBoolean() {
        #expect(CustomFieldQueryOperator.operators(for: .boolean) == [.exists, .isnull, .exact])
    }

    @Test
    func operatorsForInteger() {
        #expect(CustomFieldQueryOperator.operators(for: .integer) == [.exists, .isnull, .exact, .gt, .gte, .lt, .lte])
    }

    @Test
    func operatorsForFloat() {
        #expect(CustomFieldQueryOperator.operators(for: .float) == [.exists, .isnull, .exact, .gt, .gte, .lt, .lte])
    }

    @Test
    func operatorsForMonetary() {
        #expect(CustomFieldQueryOperator.operators(for: .monetary) == [
            .exists,
            .isnull,
            .exact,
            .icontains,
            .gt,
            .gte,
            .lt,
            .lte
        ])
    }

    @Test
    func operatorsForSelect() {
        #expect(CustomFieldQueryOperator.operators(for: .select) == [.exists, .isnull, .exact, .in])
    }

    @Test
    func operatorsForDocumentLink() {
        #expect(CustomFieldQueryOperator.operators(for: .documentLink) == [.exists, .isnull, .contains])
    }

    @Test
    func unknownDataTypeOffersNoOperators() {
        #expect(CustomFieldQueryOperator.operators(for: .unknown).isEmpty)
    }

    // The server rejects an operator its field's data type does not admit — `["AND",[[7,"gt",5]]]`
    // on a string field returns 400 "string does not support query expr 'gt'." — so no data type
    // may offer an operator outside its groups.
    @Test(arguments: CustomFieldDataType.allCases)
    func everyOfferedOperatorBelongsToAnAdmittedGroup(dataType: CustomFieldDataType) {
        let admitted = Set(CustomFieldQueryOperatorGroup.groups(for: dataType).flatMap(\.operators))
        #expect(Set(CustomFieldQueryOperator.operators(for: dataType)).subtracting(admitted).isEmpty)
    }

    @Test(arguments: [
        (CustomFieldQueryOperator.exists, CustomFieldQueryValueKind.boolean),
        (.isnull, .boolean),
        (.icontains, .string),
        (.exact, .string),
        (.gte, .string),
        (.lte, .string),
        (.gt, .number),
        (.lt, .number),
        (.contains, .array),
        (.in, .array),
    ])
    func valueKind(queryOperator: CustomFieldQueryOperator, kind: CustomFieldQueryValueKind) {
        #expect(queryOperator.valueKind == kind)
    }

    @Test
    func rawValuesAreTheWireStrings() {
        #expect(CustomFieldQueryOperator.allCases.map(\.rawValue).sorted() == [
            "contains",
            "exact",
            "exists",
            "gt",
            "gte",
            "icontains",
            "in",
            "isnull",
            "lt",
            "lte",
        ])
    }
}
