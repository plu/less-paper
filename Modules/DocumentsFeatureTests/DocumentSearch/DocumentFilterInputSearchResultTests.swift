@testable import DocumentsFeature

import ApiInterface
import Foundation
import Testing
import TestSupport

@Suite(
    .testDependencies()
)
struct DocumentFilterInputSearchResultTests {

    @Test
    func searchResult_tag() {
        let tag = Tag.testValue(id: 7, name: "Manual")

        let input = DocumentFilterInput.searchResult(tag: tag)

        #expect(input.tag.rule == .any)
        #expect(input.tag.selection.any == [tag])
        #expect(input.filterRules == [.init(ruleType: .hasTagsAny, value: "7")])
    }

    @Test
    func searchResult_correspondent() {
        let correspondent = Correspondent.testValue(id: 4)

        let input = DocumentFilterInput.searchResult(correspondent: correspondent)

        #expect(input.correspondent.rule == .include)
        #expect(input.correspondent.selection == [correspondent])
        #expect(input.filterRules == [.init(ruleType: .hasCorrespondentAny, value: "4")])
    }

    @Test
    func searchResult_documentType() {
        let documentType = DocumentType.testValue(id: 5)

        let input = DocumentFilterInput.searchResult(documentType: documentType)

        #expect(input.documentType.rule == .include)
        #expect(input.documentType.selection == [documentType])
        #expect(input.filterRules == [.init(ruleType: .hasDocumentTypeAny, value: "5")])
    }

    @Test
    func searchResult_storagePath() {
        let storagePath = StoragePath.testValue(id: 3)

        let input = DocumentFilterInput.searchResult(storagePath: storagePath)

        #expect(input.storagePath.rule == .include)
        #expect(input.storagePath.selection == [storagePath])
        #expect(input.filterRules == [.init(ruleType: .hasStoragePathAny, value: "3")])
    }

    @Test
    func searchResult_customField() {
        let customField = CustomField.testValue(id: 2, name: "Reference")

        let input = DocumentFilterInput.searchResult(customField: customField)

        #expect(input.customFieldQuery == .atom(.init(field: 2, op: .exists, value: .bool(true))))
    }

    // A tap replaces the filter rather than adding to it, so nothing else may survive in what it
    // produces. Spelled out whole rather than field by field: a per-field check silently leaves out
    // whatever the next field to be added is, and it left `date`, `sort`, `asnType` and all three
    // `.rule`s unasserted.
    @Test
    func searchResult_leavesEverythingElseAtItsDefault() {
        let tag = Tag.testValue(id: 7)

        let input = DocumentFilterInput.searchResult(tag: tag)

        #expect(
            input == DocumentFilterInput(
                asnType: .equals,
                correspondent: .init(rule: .include, selection: []),
                customFieldQuery: nil,
                date: .init(
                    from: .init(date: nil, ruleType: nil),
                    to: .init(date: nil, ruleType: nil),
                    type: .created
                ),
                documentType: .init(rule: .include, selection: []),
                searchType: .titleContent,
                searchValue: "",
                sort: .init(direction: .descending, field: .added),
                storagePath: .init(rule: .include, selection: []),
                tag: .init(rule: .any, selection: .init(all: .init(), any: [tag])),
                unsupportedFilterRules: []
            )
        )
    }
}
