@testable import DocumentsFeature

import ApiInterface
import Foundation
import Testing
import TestSupport

@Suite
struct DocumentBulkEditGenericValueTests {

    @Test
    func test_correspondent_documentCounts() async throws {
        let counts = Correspondent.documentCounts(selectionData: .testValue(
            selectedCorrespondents: [
                .init(documentCount: 2, id: 1),
                .init(documentCount: 5, id: 7)
            ]
        ))

        #expect(counts == [1: 2, 7: 5])
    }

    @Test
    func test_correspondent_method() async throws {
        #expect(Correspondent.method(id: 42) == .setCorrespondent(.init(correspondent: 42)))
        #expect(Correspondent.method(id: nil) == .setCorrespondent(.init(correspondent: nil)))
    }

    @Test
    func test_documentType_documentCounts() async throws {
        let counts = DocumentType.documentCounts(selectionData: .testValue(
            selectedDocumentTypes: [
                .init(documentCount: 3, id: 2),
                .init(documentCount: 1, id: 9)
            ]
        ))

        #expect(counts == [2: 3, 9: 1])
    }

    @Test
    func test_documentType_method() async throws {
        #expect(DocumentType.method(id: 43) == .setDocumentType(.init(documentType: 43)))
        #expect(DocumentType.method(id: nil) == .setDocumentType(.init(documentType: nil)))
    }

    @Test
    func test_storagePath_documentCounts() async throws {
        let counts = StoragePath.documentCounts(selectionData: .testValue(
            selectedStoragePaths: [
                .init(documentCount: 4, id: 3),
                .init(documentCount: 6, id: 8)
            ]
        ))

        #expect(counts == [3: 4, 8: 6])
    }

    @Test
    func test_storagePath_method() async throws {
        #expect(StoragePath.method(id: 44) == .setStoragePath(.init(storagePath: 44)))
        #expect(StoragePath.method(id: nil) == .setStoragePath(.init(storagePath: nil)))
    }
}
