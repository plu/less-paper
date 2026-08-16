@testable import DocumentsFeature

import ApiInterface
import Dependencies
import Foundation
import Testing
import TestSupport

@Suite(
    .dependencies {
        $0.apiCache.correspondent = { id, _ in id == 1 ? .testValue(id: 1, name: "Stadtwerke") : nil }
        $0.apiCache.documentType = { id, _ in id == 1 ? .testValue(id: 1, name: "Invoice") : nil }
        $0.apiCache.tag = { id, _ in
            switch id {
            case 1: .testValue(id: 1, name: "Bill")
            case 2: .testValue(id: 2, name: "2026")
            default: nil
            }
        }
        $0.apiCache.user = { id, _ in id == 1 ? .testValue(id: 1, username: "plu") : nil }
        $0.locale = Locale(identifier: "en_US")
    }
)
struct DocumentBulkEditTitleTemplateTests {

    @Test
    func test_title_expandsDocumentPlaceholders() async throws {
        let template = DocumentBulkEditTitleTemplate(
            text: "{title}|{asn}|{doc_pk}|{correspondent}|{document_type}|{tag_list}|{owner_username}"
        )

        #expect(template.title(for: document, server: .testValue()) == "Invoice 42|7|3|Stadtwerke|Invoice|Bill,2026|plu")
    }

    @Test
    func test_title_expandsCreatedPlaceholders() async throws {
        let template = DocumentBulkEditTitleTemplate(
            text: "{created_year}|{created_year_short}|{created_month}|{created_month_name}|{created_month_name_short}|{created_day}"
        )

        #expect(template.title(for: document, server: .testValue()) == "2026|26|03|March|Mar|11")
    }

    @Test
    func test_title_expandsAddedPlaceholders() async throws {
        let template = DocumentBulkEditTitleTemplate(text: "{added_year}|{added_month}|{added_day}")

        #expect(template.title(for: document, server: .testValue()) == "2026|04|01")
    }

    @Test
    func test_title_expandsIsoDates() async throws {
        let template = DocumentBulkEditTitleTemplate(text: "{created}|{added}")

        #expect(template.title(for: document, server: .testValue()) == "2026-03-11T00:00:00Z|2026-04-01T00:00:00Z")
    }

    @Test
    func test_title_stripsExtensionFromOriginalName() async throws {
        let template = DocumentBulkEditTitleTemplate(text: "{original_name}")

        #expect(template.title(for: document, server: .testValue()) == "scan_0001")
    }

    @Test
    func test_title_yieldsEmptyStringForMissingValues() async throws {
        let template = DocumentBulkEditTitleTemplate(
            text: "[{asn}][{correspondent}][{document_type}][{tag_list}][{owner_username}][{original_name}]"
        )
        let bare = Document.testValue(
            archiveSerialNumber: nil,
            correspondent: nil,
            documentType: nil,
            originalFileName: nil,
            owner: nil,
            tags: []
        )

        #expect(template.title(for: bare, server: .testValue()) == "[][][][][][]")
    }

    @Test
    func test_title_leavesUnknownTokensInPlace() async throws {
        let template = DocumentBulkEditTitleTemplate(text: "{nope}-{title}-{}")

        #expect(template.title(for: document, server: .testValue()) == "{nope}-Invoice 42-{}")
    }

    @Test
    func test_title_doesNotReExpandSubstitutedText() async throws {
        let template = DocumentBulkEditTitleTemplate(text: "{title}")
        let tricky = Document.testValue(title: "{created_year} report")

        #expect(template.title(for: tricky, server: .testValue()) == "{created_year} report")
    }

    @Test
    func test_title_withoutPlaceholdersIsLiteral() async throws {
        let template = DocumentBulkEditTitleTemplate(text: "Archived")

        #expect(template.title(for: document, server: .testValue()) == "Archived")
    }

    private var document: Document {
        .testValue(
            added: Date(timeIntervalSince1970: 1_775_001_600),
            archiveSerialNumber: 7,
            correspondent: 1,
            created: Date(timeIntervalSince1970: 1_773_187_200),
            documentType: 1,
            id: 3,
            originalFileName: "scan_0001.pdf",
            owner: 1,
            tags: [1, 2],
            title: "Invoice 42"
        )
    }
}
