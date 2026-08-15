@testable import ApiInterface
@testable import DocumentsFeature

import ComposableArchitecture
import CorrespondentsFeature
import CustomDump
import Dependencies
import DocumentTypesFeature
import Foundation
import IdentifiedCollections
import StoragePathsFeature
import SwiftSharing
import TagsFeature
import Testing
import TestSupport

@Suite(
    .dependencies()
)
struct DocumentFilterInputTests {
    @Test
    func defaultValues() async throws {
        let input = DocumentFilterInput()

        #expect(input.asnType == .equals)
        #expect(input.correspondent.rule == .include)
        #expect(input.correspondent.selection.isEmpty)
        #expect(input.documentType.rule == .include)
        #expect(input.documentType.selection.isEmpty)
        #expect(input.searchType == .titleContent)
        #expect(input.searchValue == "")
        #expect(input.storagePath.rule == .include)
        #expect(input.storagePath.selection.isEmpty)
        #expect(input.tag.rule == .all)
        #expect(input.tag.selection.all.include.isEmpty)
        #expect(input.tag.selection.all.exclude.isEmpty)
        #expect(input.tag.selection.any.isEmpty)
    }

    @Test(arguments: [
        (DocumentFilterSearchType.titleContent, FilterRuleType.titleContent),
        (DocumentFilterSearchType.title, FilterRuleType.title),
        (DocumentFilterSearchType.customFields, FilterRuleType.customFieldsText),
        (DocumentFilterSearchType.advanced, FilterRuleType.fulltextQuery),
    ])
    func filterRulesWithSearchType(
        searchType: DocumentFilterSearchType,
        expectedRuleType: FilterRuleType
    ) async throws {
        var input = DocumentFilterInput()
        input.searchType = searchType
        input.searchValue = "test"

        let filterRules = input.filterRules.sorted()

        expectNoDifference(filterRules, [
            .init(ruleType: expectedRuleType, value: "test")
        ])
    }

    @Test
    func filterRulesWithEmptySearchValue() async throws {
        var input = DocumentFilterInput()
        input.searchType = .titleContent
        input.searchValue = ""

        let filterRules = input.filterRules.sorted()

        expectNoDifference(filterRules, [])
    }

    @Test(arguments: [
        (DocumentFilterASNType.equals, FilterRuleType.asn, "123"),
        (DocumentFilterASNType.greaterThan, FilterRuleType.asnGreaterThan, "100"),
        (DocumentFilterASNType.lowerThan, FilterRuleType.asnLowerThan, "200"),
    ])
    func filterRulesWithAsnType(
        asnType: DocumentFilterASNType,
        expectedRuleType: FilterRuleType,
        searchValue: String
    ) async throws {
        var input = DocumentFilterInput()
        input.searchType = .asn
        input.asnType = asnType
        input.searchValue = searchValue

        let filterRules = input.filterRules.sorted()

        expectNoDifference(filterRules, [.init(ruleType: expectedRuleType, value: searchValue)])
    }

    @Test
    func filterRulesWithAsnIsEmpty() async throws {
        var input = DocumentFilterInput()
        input.searchType = .asn
        input.asnType = .isEmpty

        let filterRules = input.filterRules.sorted()

        expectNoDifference(filterRules, [.init(ruleType: .asnIsNull, value: "true")])
    }

    @Test
    func filterRulesWithAsnIsNotEmpty() async throws {
        var input = DocumentFilterInput()
        input.searchType = .asn
        input.asnType = .isNotEmpty

        let filterRules = input.filterRules.sorted()

        expectNoDifference(filterRules, [.init(ruleType: .asnIsNull, value: "false")])
    }

    @Test
    func filterRulesWithCorrespondentInclude() async throws {
        var input = DocumentFilterInput()
        input.correspondent.rule = .include
        input.correspondent.selection = [.testValue(id: 1), .testValue(id: 2)]

        let filterRules = input.filterRules.sorted()

        expectNoDifference(filterRules, [
            .init(ruleType: .hasCorrespondentAny, value: "1"),
            .init(ruleType: .hasCorrespondentAny, value: "2"),
        ])
    }

    @Test
    func filterRulesWithCorrespondentExclude() async throws {
        var input = DocumentFilterInput()
        input.correspondent.rule = .exclude
        input.correspondent.selection = [.testValue(id: 1), .testValue(id: 2)]

        let filterRules = input.filterRules.sorted()

        expectNoDifference(filterRules, [
            .init(ruleType: .doesNotHaveCorrespondent, value: "1"),
            .init(ruleType: .doesNotHaveCorrespondent, value: "2"),
        ])
    }

    @Test
    func filterRulesWithCorrespondentNotAssigned() async throws {
        var input = DocumentFilterInput()
        input.correspondent.rule = .notAssigned

        let filterRules = input.filterRules.sorted()

        expectNoDifference(filterRules, [.init(ruleType: .correspondent, value: nil)])
    }

    @Test
    func filterRulesWithCorrespondentIncludeEmptySelection() async throws {
        var input = DocumentFilterInput()
        input.correspondent.rule = .include
        input.correspondent.selection = []

        let filterRules = input.filterRules.sorted()

        expectNoDifference(filterRules, [])
    }

    @Test
    func filterRulesWithCorrespondentExcludeEmptySelection() async throws {
        var input = DocumentFilterInput()
        input.correspondent.rule = .exclude
        input.correspondent.selection = []

        let filterRules = input.filterRules.sorted()

        expectNoDifference(filterRules, [])
    }

    @Test
    func filterRulesWithDocumentTypeInclude() async throws {
        var input = DocumentFilterInput()
        input.documentType.rule = .include
        input.documentType.selection = [.testValue(id: 1), .testValue(id: 2)]

        let filterRules = input.filterRules.sorted()

        expectNoDifference(filterRules, [
            .init(ruleType: .hasDocumentTypeAny, value: "1"),
            .init(ruleType: .hasDocumentTypeAny, value: "2"),
        ])
    }

    @Test
    func filterRulesWithDocumentTypeExclude() async throws {
        var input = DocumentFilterInput()
        input.documentType.rule = .exclude
        input.documentType.selection = [.testValue(id: 1), .testValue(id: 2)]

        let filterRules = input.filterRules.sorted()

        expectNoDifference(filterRules, [
            .init(ruleType: .doesNotHaveDocumentType, value: "1"),
            .init(ruleType: .doesNotHaveDocumentType, value: "2"),
        ])
    }

    @Test
    func filterRulesWithDocumentTypeNotAssigned() async throws {
        var input = DocumentFilterInput()
        input.documentType.rule = .notAssigned

        let filterRules = input.filterRules.sorted()

        expectNoDifference(filterRules, [.init(ruleType: .documentType, value: nil)])
    }

    @Test
    func filterRulesWithDocumentTypeIncludeEmptySelection() async throws {
        var input = DocumentFilterInput()
        input.documentType.rule = .include
        input.documentType.selection = []

        let filterRules = input.filterRules.sorted()

        expectNoDifference(filterRules, [])
    }

    @Test
    func filterRulesWithDocumentTypeExcludeEmptySelection() async throws {
        var input = DocumentFilterInput()
        input.documentType.rule = .exclude
        input.documentType.selection = []

        let filterRules = input.filterRules.sorted()

        expectNoDifference(filterRules, [])
    }

    @Test
    func filterRulesWithStoragePathInclude() async throws {
        var input = DocumentFilterInput()
        input.storagePath.rule = .include
        input.storagePath.selection = [.testValue(id: 1), .testValue(id: 2)]

        let filterRules = input.filterRules.sorted()

        expectNoDifference(filterRules, [
            .init(ruleType: .hasStoragePathAny, value: "1"),
            .init(ruleType: .hasStoragePathAny, value: "2"),
        ])
    }

    @Test
    func filterRulesWithStoragePathExclude() async throws {
        var input = DocumentFilterInput()
        input.storagePath.rule = .exclude
        input.storagePath.selection = [.testValue(id: 1), .testValue(id: 2)]

        let filterRules = input.filterRules.sorted()

        expectNoDifference(filterRules, [
            .init(ruleType: .doesNotHaveStoragePath, value: "1"),
            .init(ruleType: .doesNotHaveStoragePath, value: "2"),
        ])
    }

    @Test
    func filterRulesWithStoragePathNotAssigned() async throws {
        var input = DocumentFilterInput()
        input.storagePath.rule = .notAssigned

        let filterRules = input.filterRules.sorted()

        expectNoDifference(filterRules, [.init(ruleType: .storagePath, value: nil)])
    }

    @Test
    func filterRulesWithStoragePathIncludeEmptySelection() async throws {
        var input = DocumentFilterInput()
        input.storagePath.rule = .include
        input.storagePath.selection = []

        let filterRules = input.filterRules.sorted()

        expectNoDifference(filterRules, [])
        #expect(!filterRules.contains { $0.ruleType == .hasStoragePathAny })
    }

    @Test
    func filterRulesWithStoragePathExcludeEmptySelection() async throws {
        var input = DocumentFilterInput()
        input.storagePath.rule = .exclude
        input.storagePath.selection = []

        let filterRules = input.filterRules.sorted()

        #expect(!filterRules.contains { $0.ruleType == .doesNotHaveStoragePath })
    }

    @Test
    func filterRulesWithTagAllInclude() async throws {
        var input = DocumentFilterInput()
        input.tag.rule = .all
        input.tag.selection.all.include = [.testValue(id: 1), .testValue(id: 2)]

        let filterRules = input.filterRules.sorted()

        expectNoDifference(filterRules, [
            .init(ruleType: .hasTagsAll, value: "1"),
            .init(ruleType: .hasTagsAll, value: "2"),
        ])
    }

    @Test
    func filterRulesWithTagAllExclude() async throws {
        var input = DocumentFilterInput()
        input.tag.rule = .all
        input.tag.selection.all.exclude = [.testValue(id: 1), .testValue(id: 2)]

        let filterRules = input.filterRules.sorted()

        expectNoDifference(filterRules, [
            .init(ruleType: .doesNotHaveTag, value: "1"),
            .init(ruleType: .doesNotHaveTag, value: "2"),
        ])
    }

    @Test
    func filterRulesWithTagAllIncludeAndExclude() async throws {
        var input = DocumentFilterInput()
        input.tag.rule = .all
        input.tag.selection.all.include = [.testValue(id: 1)]
        input.tag.selection.all.exclude = [.testValue(id: 2)]

        let filterRules = input.filterRules.sorted()

        expectNoDifference(filterRules, [
            .init(ruleType: .hasTagsAll, value: "1"),
            .init(ruleType: .doesNotHaveTag, value: "2"),
        ])
    }

    @Test
    func filterRulesWithTagAny() async throws {
        var input = DocumentFilterInput()
        input.tag.rule = .any
        input.tag.selection.any = [.testValue(id: 1), .testValue(id: 2)]

        let filterRules = input.filterRules.sorted()

        expectNoDifference(filterRules, [
            .init(ruleType: .hasTagsAny, value: "1"),
            .init(ruleType: .hasTagsAny, value: "2"),
        ])
    }

    @Test
    func filterRulesWithTagNotAssigned() async throws {
        var input = DocumentFilterInput()
        input.tag.rule = .notAssigned

        let filterRules = input.filterRules.sorted()

        expectNoDifference(filterRules, [.init(ruleType: .hasAnyTag, value: "0")])
    }

    @Test
    func filterRulesWithTagAllEmptySelection() async throws {
        var input = DocumentFilterInput()
        input.tag.rule = .all
        input.tag.selection.all.include = []
        input.tag.selection.all.exclude = []

        let filterRules = input.filterRules.sorted()

        expectNoDifference(filterRules, [])
    }

    @Test
    func filterRulesWithTagAnyEmptySelection() async throws {
        var input = DocumentFilterInput()
        input.tag.rule = .any
        input.tag.selection.any = []

        let filterRules = input.filterRules.sorted()

        expectNoDifference(filterRules, [])
    }

    @Test
    func filterRulesWithMultipleFilters() async throws {
        let correspondent = Correspondent.testValue(id: 1, name: "Test Correspondent")
        let documentType = DocumentType.testValue(id: 2, name: "Test Type")

        var input = DocumentFilterInput()
        input.searchType = .titleContent
        input.searchValue = "invoice"
        input.correspondent.rule = .include
        input.correspondent.selection = [correspondent]
        input.documentType.rule = .exclude
        input.documentType.selection = [documentType]
        input.storagePath.rule = .notAssigned

        let filterRules = input.filterRules.sorted()

        expectNoDifference(filterRules, [
            .init(ruleType: .titleContent, value: "invoice"),
            .init(ruleType: .storagePath, value: nil),
            .init(ruleType: .hasCorrespondentAny, value: "1"),
            .init(ruleType: .doesNotHaveDocumentType, value: "2"),
        ])
    }

    @Test
    func testValueWithDefaults() async throws {
        let input = DocumentFilterInput.testValue()

        #expect(input.correspondent.rule == .include)
        #expect(input.correspondent.selection.isEmpty)
        #expect(input.documentType.rule == .include)
        #expect(input.documentType.selection.isEmpty)
        #expect(input.searchType == .titleContent)
        #expect(input.searchValue == "")
    }

    @Test
    func testValueWithCustomValues() async throws {
        let correspondent = Correspondent.testValue(id: 1)
        let documentType = DocumentType.testValue(id: 2)
        let input = DocumentFilterInput.testValue(
            correspondent: .init(rule: .exclude, selection: [correspondent]),
            documentType: .init(rule: .include, selection: [documentType]),
            searchType: .asn,
            searchValue: "123"
        )

        #expect(input.correspondent.rule == .exclude)
        #expect(input.correspondent.selection.contains(correspondent))
        #expect(input.documentType.rule == .include)
        #expect(input.documentType.selection.contains(documentType))
        #expect(input.searchType == .asn)
        #expect(input.searchValue == "123")
    }

    @Test(arguments: [
        (FilterRuleType.titleContent, DocumentFilterSearchType.titleContent),
        (FilterRuleType.title, DocumentFilterSearchType.title),
        (FilterRuleType.customFieldsText, DocumentFilterSearchType.customFields),
    ])
    func initWithSearchTypeFilterRule(
        ruleType: FilterRuleType,
        expectedSearchType: DocumentFilterSearchType
    ) async throws {
        let filterRules = [FilterRule(ruleType: ruleType, value: "test")]
        let input = DocumentFilterInput(
            filterRules: filterRules,
            server: .testValue(),
            sortDirection: .descending,
            sortField: .added
        )

        expectNoDifference(input, DocumentFilterInput(
            searchType: expectedSearchType,
            searchValue: "test"
        ))
    }

    @Test
    func initWithAsnEquals() async throws {
        let filterRules = [FilterRule(ruleType: .asn, value: "123")]
        let input = DocumentFilterInput(
            filterRules: filterRules,
            server: .testValue(),
            sortDirection: .descending,
            sortField: .added
        )

        expectNoDifference(input, DocumentFilterInput(
            asnType: .equals,
            searchType: .asn,
            searchValue: "123"
        ))
    }

    @Test(arguments: [
        ("true", DocumentFilterASNType.isEmpty),
        ("false", DocumentFilterASNType.isNotEmpty),
    ])
    func initWithAsnIsNull(value: String, expectedAsnType: DocumentFilterASNType) async throws {
        let filterRules = [FilterRule(ruleType: .asnIsNull, value: value)]
        let input = DocumentFilterInput(
            filterRules: filterRules,
            server: .testValue(),
            sortDirection: .descending,
            sortField: .added
        )

        expectNoDifference(input, DocumentFilterInput(
            asnType: expectedAsnType,
            searchType: .asn
        ))
    }

    @Test
    func initWithAsnGreaterThan() async throws {
        let filterRules = [FilterRule(ruleType: .asnGreaterThan, value: "100")]
        let input = DocumentFilterInput(
            filterRules: filterRules,
            server: .testValue(),
            sortDirection: .descending,
            sortField: .added
        )

        expectNoDifference(input, DocumentFilterInput(
            asnType: .greaterThan,
            searchType: .asn,
            searchValue: "100"
        ))
    }

    @Test
    func initWithAsnLowerThan() async throws {
        let filterRules = [FilterRule(ruleType: .asnLowerThan, value: "200")]
        let input = DocumentFilterInput(
            filterRules: filterRules,
            server: .testValue(),
            sortDirection: .descending,
            sortField: .added
        )

        expectNoDifference(input, DocumentFilterInput(
            asnType: .lowerThan,
            searchType: .asn,
            searchValue: "200"
        ))
    }

    @Test
    func initWithCorrespondentNotAssigned() async throws {
        let filterRules = [FilterRule(ruleType: .correspondent, value: nil)]
        let input = DocumentFilterInput(
            filterRules: filterRules,
            server: .testValue(),
            sortDirection: .descending,
            sortField: .added
        )

        expectNoDifference(input, DocumentFilterInput(
            correspondent: .init(
                rule: .notAssigned,
                selection: []
            )
        ))
    }

    @Test
    func initWithHasCorrespondentAny() async throws {
        let correspondent1 = Correspondent.testValue(id: 1)
        let correspondent2 = Correspondent.testValue(id: 2)
        @Shared(.correspondents(.testValue()))
        var correspondents: IdentifiedArrayOf<Correspondent> = [correspondent1, correspondent2]

        let filterRules = [FilterRule(ruleType: .hasCorrespondentAny, value: "1,2")]
        let input = DocumentFilterInput(
            filterRules: filterRules,
            server: .testValue(),
            sortDirection: .descending,
            sortField: .added
        )

        expectNoDifference(input, DocumentFilterInput(
            correspondent: .init(
                rule: .include,
                selection: [correspondent1, correspondent2]
            )
        ))
    }

    @Test
    func initWithDoesNotHaveCorrespondent() async throws {
        let correspondent1 = Correspondent.testValue(id: 1)
        let correspondent2 = Correspondent.testValue(id: 2)
        @Shared(.correspondents(.testValue()))
        var correspondents: IdentifiedArrayOf<Correspondent> = [correspondent1, correspondent2]

        let filterRules = [FilterRule(ruleType: .doesNotHaveCorrespondent, value: "1,2")]
        let input = DocumentFilterInput(
            filterRules: filterRules,
            server: .testValue(),
            sortDirection: .descending,
            sortField: .added
        )

        expectNoDifference(input, DocumentFilterInput(
            correspondent: .init(
                rule: .exclude,
                selection: [correspondent1, correspondent2]
            )
        ))
    }

    @Test
    func initWithDocumentTypeNotAssigned() async throws {
        let filterRules = [FilterRule(ruleType: .documentType, value: nil)]
        let input = DocumentFilterInput(
            filterRules: filterRules,
            server: .testValue(),
            sortDirection: .descending,
            sortField: .added
        )

        expectNoDifference(input, DocumentFilterInput(
            documentType: .init(
                rule: .notAssigned,
                selection: []
            )
        ))
    }

    @Test
    func initWithHasDocumentTypeAny() async throws {
        let documentType1 = DocumentType.testValue(id: 1)
        let documentType2 = DocumentType.testValue(id: 2)
        @Shared(.documentTypes(.testValue()))
        var documentTypes: IdentifiedArrayOf<DocumentType> = [documentType1, documentType2]

        let filterRules = [FilterRule(ruleType: .hasDocumentTypeAny, value: "1,2")]
        let input = DocumentFilterInput(
            filterRules: filterRules,
            server: .testValue(),
            sortDirection: .descending,
            sortField: .added
        )

        expectNoDifference(input, DocumentFilterInput(
            documentType: .init(
                rule: .include,
                selection: [documentType1, documentType2]
            )
        ))
    }

    @Test
    func initWithDoesNotHaveDocumentType() async throws {
        let documentType1 = DocumentType.testValue(id: 1)
        let documentType2 = DocumentType.testValue(id: 2)
        @Shared(.documentTypes(.testValue()))
        var documentTypes: IdentifiedArrayOf<DocumentType> = [documentType1, documentType2]

        let filterRules = [FilterRule(ruleType: .doesNotHaveDocumentType, value: "1,2")]
        let input = DocumentFilterInput(
            filterRules: filterRules,
            server: .testValue(),
            sortDirection: .descending,
            sortField: .added
        )

        expectNoDifference(input, DocumentFilterInput(
            documentType: .init(
                rule: .exclude,
                selection: [documentType1, documentType2]
            )
        ))
    }

    @Test
    func initWithStoragePathNotAssigned() async throws {
        let filterRules = [FilterRule(ruleType: .storagePath, value: nil)]
        let input = DocumentFilterInput(
            filterRules: filterRules,
            server: .testValue(),
            sortDirection: .descending,
            sortField: .added
        )

        expectNoDifference(input, DocumentFilterInput(
            storagePath: .init(
                rule: .notAssigned,
                selection: []
            )
        ))
    }

    @Test
    func initWithHasStoragePathAny() async throws {
        let storagePath1 = StoragePath.testValue(id: 1)
        let storagePath2 = StoragePath.testValue(id: 2)
        @Shared(.storagePaths(.testValue()))
        var storagePaths: IdentifiedArrayOf<StoragePath> = [storagePath1, storagePath2]

        let filterRules = [FilterRule(ruleType: .hasStoragePathAny, value: "1,2")]
        let input = DocumentFilterInput(
            filterRules: filterRules,
            server: .testValue(),
            sortDirection: .descending,
            sortField: .added
        )

        expectNoDifference(input, DocumentFilterInput(
            storagePath: .init(
                rule: .include,
                selection: [storagePath1, storagePath2]
            )
        ))
    }

    @Test
    func initWithDoesNotHaveStoragePath() async throws {
        let storagePath1 = StoragePath.testValue(id: 1)
        let storagePath2 = StoragePath.testValue(id: 2)
        @Shared(.storagePaths(.testValue()))
        var storagePaths: IdentifiedArrayOf<StoragePath> = [storagePath1, storagePath2]

        let filterRules = [FilterRule(ruleType: .doesNotHaveStoragePath, value: "1,2")]
        let input = DocumentFilterInput(
            filterRules: filterRules,
            server: .testValue(),
            sortDirection: .descending,
            sortField: .added
        )

        expectNoDifference(input, DocumentFilterInput(
            storagePath: .init(
                rule: .exclude,
                selection: [storagePath1, storagePath2]
            )
        ))
    }

    @Test
    func initWithTagNotAssigned() async throws {
        let filterRules = [FilterRule(ruleType: .hasAnyTag, value: "0")]
        let input = DocumentFilterInput(
            filterRules: filterRules,
            server: .testValue(),
            sortDirection: .descending,
            sortField: .added
        )

        expectNoDifference(input, DocumentFilterInput(
            tag: .init(rule: .notAssigned)
        ))
    }

    @Test
    func initWithHasTagsAll() async throws {
        let tag1 = Tag.testValue(id: 1)
        let tag2 = Tag.testValue(id: 2)
        @Shared(.tags(.testValue()))
        var tags: IdentifiedArrayOf<ApiInterface.Tag> = [tag1, tag2]

        let filterRules = [FilterRule(ruleType: .hasTagsAll, value: "1,2")]
        let input = DocumentFilterInput(
            filterRules: filterRules,
            server: .testValue(),
            sortDirection: .descending,
            sortField: .added
        )

        expectNoDifference(input, DocumentFilterInput(
            tag: .init(
                rule: .all,
                selection: .testValue(all: .testValue(include: [tag1, tag2]))
            )
        ))
    }

    @Test
    func initWithDoesNotHaveTag() async throws {
        let tag1 = Tag.testValue(id: 1)
        let tag2 = Tag.testValue(id: 2)
        @Shared(.tags(.testValue()))
        var tags: IdentifiedArrayOf<ApiInterface.Tag> = [tag1, tag2]

        let filterRules = [FilterRule(ruleType: .doesNotHaveTag, value: "1,2")]
        let input = DocumentFilterInput(
            filterRules: filterRules,
            server: .testValue(),
            sortDirection: .descending,
            sortField: .added
        )

        expectNoDifference(input, DocumentFilterInput(
            tag: .init(
                rule: .all,
                selection: .testValue(all: .testValue(exclude: [tag1, tag2]))
            )
        ))
    }

    @Test
    func initWithHasTagsAllAndDoesNotHaveTag() async throws {
        let tag1 = Tag.testValue(id: 1)
        let tag2 = Tag.testValue(id: 2)
        @Shared(.tags(.testValue()))
        var tags: IdentifiedArrayOf<ApiInterface.Tag> = [tag1, tag2]

        let filterRules = [
            FilterRule(ruleType: .hasTagsAll, value: "1"),
            FilterRule(ruleType: .doesNotHaveTag, value: "2"),
        ]
        let input = DocumentFilterInput(
            filterRules: filterRules,
            server: .testValue(),
            sortDirection: .descending,
            sortField: .added
        )

        expectNoDifference(input, DocumentFilterInput(
            tag: .init(
                rule: .all,
                selection: .testValue(all: .testValue(exclude: [tag2], include: [tag1]))
            )
        ))
    }

    @Test
    func initWithHasTagsAny() async throws {
        let tag1 = Tag.testValue(id: 1)
        let tag2 = Tag.testValue(id: 2)
        @Shared(.tags(.testValue()))
        var tags: IdentifiedArrayOf<ApiInterface.Tag> = [tag1, tag2]

        let filterRules = [FilterRule(ruleType: .hasTagsAny, value: "1,2")]
        let input = DocumentFilterInput(
            filterRules: filterRules,
            server: .testValue(),
            sortDirection: .descending,
            sortField: .added
        )

        expectNoDifference(input, DocumentFilterInput(
            tag: .init(
                rule: .any,
                selection: .testValue(any: [tag1, tag2])
            )
        ))
    }

    @Test
    func initWithTagSkipsInvalidIds() async throws {
        let tag1 = Tag.testValue(id: 1)
        @Shared(.tags(.testValue()))
        var tags: IdentifiedArrayOf<ApiInterface.Tag> = [tag1]

        let filterRules = [FilterRule(ruleType: .hasTagsAll, value: "1,42")]
        let input = DocumentFilterInput(
            filterRules: filterRules,
            server: .testValue(),
            sortDirection: .descending,
            sortField: .added
        )

        expectNoDifference(input, DocumentFilterInput(
            tag: .init(
                rule: .all,
                selection: .testValue(all: .testValue(include: [tag1]))
            )
        ))
    }

    @Test
    func initWithMultipleFilterRules() async throws {
        let correspondent = Correspondent.testValue(id: 1)
        let documentType = DocumentType.testValue(id: 2)
        let storagePath = StoragePath.testValue(id: 3)

        @Shared(.correspondents(.testValue()))
        var correspondents: IdentifiedArrayOf<Correspondent> = [correspondent]
        @Shared(.documentTypes(.testValue()))
        var documentTypes: IdentifiedArrayOf<DocumentType> = [documentType]
        @Shared(.storagePaths(.testValue()))
        var storagePaths: IdentifiedArrayOf<StoragePath> = [storagePath]

        let filterRules = [
            FilterRule(ruleType: .titleContent, value: "invoice"),
            FilterRule(ruleType: .hasCorrespondentAny, value: "1"),
            FilterRule(ruleType: .doesNotHaveDocumentType, value: "2"),
            FilterRule(ruleType: .hasStoragePathAny, value: "3"),
        ]
        let input = DocumentFilterInput(
            filterRules: filterRules,
            server: .testValue(),
            sortDirection: .descending,
            sortField: .added
        )

        expectNoDifference(input, DocumentFilterInput(
            correspondent: .init(rule: .include, selection: [correspondent]),
            documentType: .init(rule: .exclude, selection: [documentType]),
            searchType: .titleContent,
            searchValue: "invoice",
            storagePath: .init(rule: .include, selection: [storagePath])
        ))
    }

    @Test
    func initWithEmptyFilterRules() async throws {
        let input = DocumentFilterInput(
            filterRules: [],
            server: .testValue(),
            sortDirection: .descending,
            sortField: .added
        )

        #expect(input.correspondent.rule == .include)
        #expect(input.correspondent.selection.isEmpty)
        #expect(input.documentType.rule == .include)
        #expect(input.documentType.selection.isEmpty)
        #expect(input.searchType == .titleContent)
        #expect(input.searchValue == "")
        #expect(input.sort.direction == .descending)
        #expect(input.sort.field == .added)
        #expect(input.storagePath.rule == .include)
        #expect(input.storagePath.selection.isEmpty)
    }

    @Test
    func initWithUnsupportedFilterRuleType() async throws {
        let filterRules = [FilterRule(ruleType: .createdBefore, value: "2024-01-01")]
        let input = DocumentFilterInput(
            filterRules: filterRules,
            server: .testValue(),
            sortDirection: .descending,
            sortField: .added
        )

        expectNoDifference(input, DocumentFilterInput(
            unsupportedFilterRules: filterRules
        ))
    }

    @Test
    func filterRulesRoundTripKeepsUnsupportedFilterRules() async throws {
        @Shared(.documentTypes(.testValue()))
        var documentTypes: IdentifiedArrayOf<DocumentType> = [.testValue(id: 3)]

        let filterRules = [
            FilterRule(ruleType: .hasDocumentTypeAny, value: "3"),
            FilterRule(ruleType: .createdAfter, value: "2026-01-01"),
        ]
        let input = DocumentFilterInput(
            filterRules: filterRules,
            server: .testValue(),
            sortDirection: .ascending,
            sortField: .created
        )

        expectNoDifference(input.filterRules.sorted(), filterRules.sorted())
    }

    @Test
    func filterRulesRoundTripWithAdvancedSearch() async throws {
        let filterRules = [FilterRule(ruleType: .fulltextQuery, value: "invoice")]
        let input = DocumentFilterInput(
            filterRules: filterRules,
            server: .testValue(),
            sortDirection: .descending,
            sortField: .added
        )

        expectNoDifference(input, DocumentFilterInput(
            searchType: .advanced,
            searchValue: "invoice"
        ))
        expectNoDifference(input.filterRules.sorted(), filterRules.sorted())
    }

    @Test
    func skipsInvalidIds() async throws {
        @Shared(.correspondents(.testValue()))
        var correspondents: IdentifiedArrayOf<Correspondent> = [.testValue(id: 1)]
        @Shared(.documentTypes(.testValue()))
        var documentTypes: IdentifiedArrayOf<DocumentType> = [.testValue(id: 1)]
        @Shared(.storagePaths(.testValue()))
        var storagePaths: IdentifiedArrayOf<StoragePath> = [.testValue(id: 1)]

        let filterRules = [
            FilterRule(ruleType: .hasCorrespondentAny, value: "1,42"),
            FilterRule(ruleType: .hasDocumentTypeAny, value: "1,42"),
            FilterRule(ruleType: .hasStoragePathAny, value: "1,42"),
        ]
        let input = DocumentFilterInput(
            filterRules: filterRules,
            server: .testValue(),
            sortDirection: .descending,
            sortField: .added
        )

        expectNoDifference(input, DocumentFilterInput(
            correspondent: .init(rule: .include, selection: [.testValue(id: 1)]),
            documentType: .init(rule: .include, selection: [.testValue(id: 1)]),
            storagePath: .init(rule: .include, selection: [.testValue(id: 1)])
        ))
    }

    // MARK: - hasAnyTag

    /// `is_tagged=1` means "has at least one tag". Parsing it as `.notAssigned` inverted the
    /// filter, and because `runGetDocuments` sends these same rules, selecting such a saved view
    /// asked the server for untagged documents.
    @Test
    func hasAnyTagWithValueOne_parsesAsAssigned() async throws {
        let input = DocumentFilterInput(
            filterRules: [.init(ruleType: .hasAnyTag, value: "1")],
            server: .testValue(),
            sortDirection: .descending,
            sortField: .added
        )

        expectNoDifference(input.tag.rule, .assigned)
    }

    @Test
    func hasAnyTagWithValueZero_parsesAsNotAssigned() async throws {
        let input = DocumentFilterInput(
            filterRules: [.init(ruleType: .hasAnyTag, value: "0")],
            server: .testValue(),
            sortDirection: .descending,
            sortField: .added
        )

        expectNoDifference(input.tag.rule, .notAssigned)
    }

    @Test
    func filterRulesWithTagAssigned() async throws {
        var input = DocumentFilterInput()
        input.tag.rule = .assigned

        expectNoDifference(input.filterRules, [.init(ruleType: .hasAnyTag, value: "1")])
    }

    /// The whole point: a saved view survives being loaded into the sheet and written back out.
    @Test
    func hasAnyTagSurvivesARoundTrip() async throws {
        for value in ["0", "1"] {
            let original = [FilterRule(ruleType: .hasAnyTag, value: value)]
            let input = DocumentFilterInput(
                filterRules: original,
                server: .testValue(),
                sortDirection: .descending,
                sortField: .added
            )

            expectNoDifference(input.filterRules, original)
        }
    }
}
