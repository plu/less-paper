@testable import ApiImplementation

import ApiInterface
import CustomDump
import Dependencies
import Foundation
import MultipartFormDataKit
import Testing
import TestSupport

@Suite(
    .dependencies()
)
struct DocumentsRepositoryTests {

    @Test
    func createDocument_returnsVoid() async throws {
        let tempURL = try createTempTestFile()
        let input = CreateDocumentInput(
            archiveSerialNumber: nil,
            correspondent: nil,
            createdDate: Date(),
            documentType: nil,
            storagePath: nil,
            tags: [],
            title: "Test Document",
            url: tempURL
        )

        try await repository.createDocument(
            input: input,
            server: .testValue()
        )
    }

    @Test
    func formData_withMinimalFields() async throws {
        let tempURL = try createTempTestFile(content: "Test PDF content")
        let date = Date(timeIntervalSince1970: 1609459200)
        let input = CreateDocumentInput(
            archiveSerialNumber: nil,
            correspondent: nil,
            createdDate: date,
            documentType: nil,
            storagePath: nil,
            tags: [],
            title: "Minimal Document",
            url: tempURL
        )

        let formData = try input.formData

        let bodyString = String(data: formData.body, encoding: .utf8) ?? ""

        #expect(formData.contentType.contains("multipart/form-data"))
        #expect(formData.contentType.contains("boundary="))

        #expect(bodyString.contains("name=\"created\""))
        #expect(bodyString.contains("2021-01-01"))
        #expect(bodyString.contains("name=\"document\""))
        #expect(bodyString.contains("filename=\"test.pdf\""))
        #expect(bodyString.contains("Test PDF content"))
        #expect(bodyString.contains("name=\"title\""))
        #expect(bodyString.contains("Minimal Document"))

        #expect(!bodyString.contains("name=\"archive_serial_number\""))
        #expect(!bodyString.contains("name=\"correspondent\""))
        #expect(!bodyString.contains("name=\"document_type\""))
        #expect(!bodyString.contains("name=\"storage_path\""))
        #expect(!bodyString.contains("name=\"tags\""))
    }

    @Test
    func formData_withAllFields() async throws {
        let tempURL = try createTempTestFile(content: "Full document content")
        let date = Date(timeIntervalSince1970: 1609459200)
        let input = CreateDocumentInput(
            archiveSerialNumber: 12345,
            correspondent: 67890,
            createdDate: date,
            documentType: 98765,
            storagePath: 43210,
            tags: [1, 2, 3, 4],
            title: "Complete Document",
            url: tempURL
        )

        let formData = try input.formData

        let bodyString = String(data: formData.body, encoding: .utf8) ?? ""

        #expect(formData.contentType.contains("multipart/form-data"))

        #expect(bodyString.contains("name=\"created\""))
        #expect(bodyString.contains("2021-01-01"))
        #expect(bodyString.contains("name=\"document\""))
        #expect(bodyString.contains("filename=\"test.pdf\""))
        #expect(bodyString.contains("Full document content"))
        #expect(bodyString.contains("name=\"title\""))
        #expect(bodyString.contains("Complete Document"))

        #expect(bodyString.contains("name=\"archive_serial_number\""))
        #expect(bodyString.contains("12345"))
        #expect(bodyString.contains("name=\"correspondent\""))
        #expect(bodyString.contains("67890"))
        #expect(bodyString.contains("name=\"document_type\""))
        #expect(bodyString.contains("98765"))
        #expect(bodyString.contains("name=\"storage_path\""))
        #expect(bodyString.contains("43210"))

        #expect(bodyString.contains("name=\"tags\"") && bodyString.contains("1"))
        #expect(bodyString.contains("name=\"tags\"") && bodyString.contains("2"))
        #expect(bodyString.contains("name=\"tags\"") && bodyString.contains("3"))
        #expect(bodyString.contains("name=\"tags\"") && bodyString.contains("4"))

        let tagFieldCount = bodyString.components(separatedBy: "name=\"tags\"").count - 1
        #expect(tagFieldCount == 4)
    }

    @Test
    func formData_withEmptyTags() async throws {
        let tempURL = try createTempTestFile()
        let input = CreateDocumentInput(
            archiveSerialNumber: nil,
            correspondent: nil,
            createdDate: Date(),
            documentType: nil,
            storagePath: nil,
            tags: [],
            title: "No Tags Document",
            url: tempURL
        )

        let formData = try input.formData

        let bodyString = String(data: formData.body, encoding: .utf8) ?? ""

        #expect(!bodyString.contains("name=\"tags\""))
    }

    @Test
    func formData_withSingleTag() async throws {
        let tempURL = try createTempTestFile()
        let input = CreateDocumentInput(
            archiveSerialNumber: nil,
            correspondent: nil,
            createdDate: Date(),
            documentType: nil,
            storagePath: nil,
            tags: [42],
            title: "Single Tag Document",
            url: tempURL
        )

        let formData = try input.formData

        let bodyString = String(data: formData.body, encoding: .utf8) ?? ""

        let tagFieldCount = bodyString.components(separatedBy: "name=\"tags\"").count - 1
        #expect(tagFieldCount == 1)
        #expect(bodyString.contains("42"))
    }

    @Test
    func formData_withInvalidFile_throwsError() async throws {
        let nonExistentURL = URL(fileURLWithPath: "/nonexistent/file.pdf")
        let input = CreateDocumentInput(
            archiveSerialNumber: nil,
            correspondent: nil,
            createdDate: Date(),
            documentType: nil,
            storagePath: nil,
            tags: [],
            title: "Invalid File",
            url: nonExistentURL
        )

        #expect(throws: (any Error).self) {
            _ = try input.formData
        }
    }

    @Test
    func formData_generatesDifferentBoundaries() async throws {
        let tempURL = try createTempTestFile()
        let input = CreateDocumentInput.testValue(url: tempURL)

        let formData1 = try input.formData
        let formData2 = try input.formData

        #expect(formData1.contentType != formData2.contentType)

        #expect(formData1.contentType.contains("multipart/form-data"))
        #expect(formData2.contentType.contains("multipart/form-data"))

        #expect(formData1.contentType.contains("boundary="))
        #expect(formData2.contentType.contains("boundary="))
    }

    @Test(
        .dependencies {
            $0.authenticationProvider = .integrationTest
            $0.context = .live
        },
        .tags(.integrationTests)
    )
    func test_createDocument() async throws {
        let title = "Create Document Test \(UUID())"
        let input = CreateDocumentInput.testValue(
            createdDate: Date(),
            title: title,
            url: URL.projectRoot
                .appendingPathComponent("docker")
                .appendingPathComponent("data")
                .appendingPathComponent("Puky.pdf")
        )

        try await repository.createDocument(
            input: input,
            server: .testValue()
        )

        let id = try await waitForDocument(title: title)

        try await repository.bulkEditDocuments(
            input: .init(documents: [id], method: .delete),
            server: .testValue()
        )
    }

    @Test(
        .dependencies {
            $0.authenticationProvider = .integrationTest
            $0.context = .live
        },
        .tags(.integrationTests)
    )
    func test_getNextArchiveSerialNumber() async throws {
        let nextArchiveSerialNumber = try await repository.getNextArchiveSerialNumber(
            server: .testValue()
        )

        #expect(nextArchiveSerialNumber > 0)
    }

    @Test(
        .dependencies {
            $0.authenticationProvider = .integrationTest
            $0.context = .live
        },
        .tags(.integrationTests)
    )
    func test_getDocuments() async throws {
        let documents = try await repository.getDocuments(
            input: .testValue(
                filterRules: [.init(ruleType: .title, value: "Lego")],
                sortDirection: .ascending,
                sortField: .title
            ),
            server: .testValue()
        )

        #expect(documents.results.count == 2)
        #expect(documents.results.first?.title == "Lego Duplo")
        #expect(documents.results.last?.title == "Lego Friends")
    }

    @Test(
        .dependencies {
            $0.authenticationProvider = .integrationTest
            $0.context = .live
        },
        .tags(.integrationTests)
    )
    func test_getAllDocumentIds() async throws {
        let output = try await repository.getAllDocumentIds(
            input: .testValue(
                filterRules: [.init(ruleType: .title, value: "Lego")]
            ),
            server: .testValue()
        )

        #expect(output.results.count == 2)
    }

    @Test(
        .dependencies {
            $0.authenticationProvider = .integrationTest
            $0.context = .live
        },
        .tags(.integrationTests)
    )
    func test_getDocument_returnsUntruncatedContent() async throws {
        let listed = try await repository.getDocuments(
            input: .testValue(),
            server: .testValue()
        ).results

        // Paperless caps truncated content at 550 characters, so a document sitting exactly on the
        // cap is one the list has demonstrably cut short. Picking it by length rather than by title
        // keeps the test honest if the fixtures change: no candidate means #require fails loudly
        // rather than the comparison below passing vacuously on empty content.
        let truncated = try #require(listed.first { $0.content?.count == 550 })
        let truncatedContent = try #require(truncated.content)

        let fetched = try await repository.getDocument(
            id: truncated.id,
            server: .testValue()
        )
        let fetchedContent = try #require(fetched.content)

        #expect(fetched.id == truncated.id)
        #expect(fetchedContent.count > truncatedContent.count)
        #expect(fetchedContent.hasPrefix(truncatedContent))
    }

    @Test
    func test_getDocumentsByIds_emptyIds_returnsEmpty() async throws {
        let documents = try await repository.getDocumentsByIds(
            input: .init(ids: []),
            server: .testValue()
        )

        #expect(documents.isEmpty)
    }

    @Test(
        .dependencies {
            $0.authenticationProvider = .integrationTest
            $0.context = .live
        },
        .tags(.integrationTests)
    )
    func test_getDocumentsByIds() async throws {
        let allIds = try await repository.getAllDocumentIds(
            input: .testValue(
                filterRules: [.init(ruleType: .title, value: "Lego")]
            ),
            server: .testValue()
        )
        let ids = allIds.results.map(\.id)

        let documents = try await repository.getDocumentsByIds(
            input: .init(ids: ids),
            server: .testValue()
        )

        #expect(Set(documents.map(\.id)) == Set(ids))
    }

    @Test(
        .dependencies {
            $0.authenticationProvider = .integrationTest
            $0.context = .live
        },
        .tags(.integrationTests)
    )
    func test_getDocumentsByIds_ordering() async throws {
        let allIds = try await repository.getAllDocumentIds(
            input: .testValue(),
            server: .testValue()
        )
        let ids = Array(allIds.results.map(\.id).prefix(5))

        let ascending = try await repository.getDocumentsByIds(
            input: .init(ids: ids, sortDirection: .ascending, sortField: .title),
            server: .testValue()
        )
        let descending = try await repository.getDocumentsByIds(
            input: .init(ids: ids, sortDirection: .descending, sortField: .title),
            server: .testValue()
        )

        #expect(ascending.map(\.id) == descending.map(\.id).reversed())
        #expect(ascending.map(\.title) == ascending.map(\.title).sorted())
    }

    @Test(
        .dependencies {
            $0.authenticationProvider = .integrationTest
            $0.context = .live
        },
        .tags(.integrationTests)
    )
    func test_getSelectionData() async throws {
        let documentIds = try await repository.getAllDocumentIds(
            input: .testValue(
                filterRules: [.init(ruleType: .title, value: "Lego")]
            ),
            server: .testValue()
        )

        _ = try await repository.getSelectionData(
            input: .init(documents: documentIds.results.map(\.id)),
            server: .testValue()
        )
    }

    @Test(
        .dependencies {
            $0.authenticationProvider = .integrationTest
            $0.context = .live
        },
        .tags(.integrationTests)
    )
    func test_bulkEditDocuments_delete() async throws {
        let title = "Bulk Edit Delete Test \(UUID())"
        let id = try await createTestDocument(title: title)

        try await repository.bulkEditDocuments(
            input: .init(documents: [id], method: .delete),
            server: .testValue()
        )

        let output = try await repository.getAllDocumentIds(
            input: .testValue(filterRules: [.init(ruleType: .title, value: title)]),
            server: .testValue()
        )
        #expect(output.results.isEmpty)
    }

    @Test(
        .dependencies {
            $0.authenticationProvider = .integrationTest
            $0.context = .live
        },
        .tags(.integrationTests)
    )
    func test_bulkEditDocuments_merge() async throws {
        let first = try await createTestPdfDocument(title: "Bulk Edit Merge Test A \(UUID())")
        let second = try await createTestPdfDocument(title: "Bulk Edit Merge Test B \(UUID())")
        let existing = try await documentIds()

        try await repository.bulkEditDocuments(
            input: .init(
                documents: [first, second],
                method: .merge(.init(archiveFallback: true, deleteOriginals: true))
            ),
            server: .testValue()
        )

        let mergedId = try await waitForNewDocument(excluding: existing)

        try await repository.bulkEditDocuments(
            input: .init(documents: [mergedId], method: .delete),
            server: .testValue()
        )
    }

    @Test(
        .dependencies {
            $0.authenticationProvider = .integrationTest
            $0.context = .live
        },
        .tags(.integrationTests)
    )
    func test_bulkEditDocuments_modifyTags() async throws {
        let title = "Bulk Edit Modify Tags Test \(UUID())"
        let id = try await createTestDocument(title: title)
        let tag = try await tagsRepository.createTag(
            input: .init(
                color: "#ff0000",
                isInboxTag: false,
                name: "Bulk Edit Test Tag \(UUID())"
            ),
            server: .testValue()
        )

        try await repository.bulkEditDocuments(
            input: .init(
                documents: [id],
                method: .modifyTags(.init(addTags: [tag.id], removeTags: []))
            ),
            server: .testValue()
        )

        var documents = try await repository.getDocuments(
            input: .testValue(filterRules: [.init(ruleType: .title, value: title)]),
            server: .testValue()
        )
        // Not `== [tag.id]`: paperless-ngx's automatic document classifier
        // (the default `matchingAlgorithm` for every tag this codebase
        // creates, including in other integration suites running
        // concurrently against this shared fixture instance) can auto-assign
        // unrelated tags to a document at consumption time. `modify_tags` is
        // additive, so any such tag survives alongside ours. This test only
        // needs to prove our own tag was added, not that we own the array.
        #expect(documents.results.first?.tags.contains(tag.id) == true)

        try await repository.bulkEditDocuments(
            input: .init(
                documents: [id],
                method: .modifyTags(.init(addTags: [], removeTags: [tag.id]))
            ),
            server: .testValue()
        )

        documents = try await repository.getDocuments(
            input: .testValue(filterRules: [.init(ruleType: .title, value: title)]),
            server: .testValue()
        )
        #expect(documents.results.first?.tags.contains(tag.id) == false)

        try await repository.bulkEditDocuments(
            input: .init(documents: [id], method: .delete),
            server: .testValue()
        )
        try await tagsRepository.deleteTag(id: tag.id, server: .testValue())
    }

    @Test(
        .dependencies {
            $0.authenticationProvider = .integrationTest
            $0.context = .live
        },
        .tags(.integrationTests)
    )
    func test_bulkEditDocuments_setCorrespondent() async throws {
        let title = "Bulk Edit Set Correspondent Test \(UUID())"
        let id = try await createTestDocument(title: title)
        let correspondent = try await correspondentsRepository.createCorrespondent(
            input: .init(name: "Bulk Edit Test Correspondent \(UUID())"),
            server: .testValue()
        )

        try await repository.bulkEditDocuments(
            input: .init(
                documents: [id],
                method: .setCorrespondent(.init(correspondent: correspondent.id))
            ),
            server: .testValue()
        )

        var documents = try await repository.getDocuments(
            input: .testValue(filterRules: [.init(ruleType: .title, value: title)]),
            server: .testValue()
        )
        #expect(documents.results.first?.correspondent == correspondent.id)

        try await repository.bulkEditDocuments(
            input: .init(
                documents: [id],
                method: .setCorrespondent(.init(correspondent: nil))
            ),
            server: .testValue()
        )

        documents = try await repository.getDocuments(
            input: .testValue(filterRules: [.init(ruleType: .title, value: title)]),
            server: .testValue()
        )
        #expect(documents.results.first?.correspondent == nil)

        try await repository.bulkEditDocuments(
            input: .init(documents: [id], method: .delete),
            server: .testValue()
        )
        try await correspondentsRepository.deleteCorrespondent(id: correspondent.id, server: .testValue())
    }

    @Test(
        .dependencies {
            $0.authenticationProvider = .integrationTest
            $0.context = .live
        },
        .tags(.integrationTests)
    )
    func test_bulkEditDocuments_setDocumentType() async throws {
        let title = "Bulk Edit Set Document Type Test \(UUID())"
        let id = try await createTestDocument(title: title)
        let documentType = try await documentTypesRepository.createDocumentType(
            input: .init(name: "Bulk Edit Test Document Type \(UUID())"),
            server: .testValue()
        )

        try await repository.bulkEditDocuments(
            input: .init(
                documents: [id],
                method: .setDocumentType(.init(documentType: documentType.id))
            ),
            server: .testValue()
        )

        var documents = try await repository.getDocuments(
            input: .testValue(filterRules: [.init(ruleType: .title, value: title)]),
            server: .testValue()
        )
        #expect(documents.results.first?.documentType == documentType.id)

        try await repository.bulkEditDocuments(
            input: .init(
                documents: [id],
                method: .setDocumentType(.init(documentType: nil))
            ),
            server: .testValue()
        )

        documents = try await repository.getDocuments(
            input: .testValue(filterRules: [.init(ruleType: .title, value: title)]),
            server: .testValue()
        )
        #expect(documents.results.first?.documentType == nil)

        try await repository.bulkEditDocuments(
            input: .init(documents: [id], method: .delete),
            server: .testValue()
        )
        try await documentTypesRepository.deleteDocumentType(id: documentType.id, server: .testValue())
    }

    @Test(
        .dependencies {
            $0.authenticationProvider = .integrationTest
            $0.context = .live
        },
        .tags(.integrationTests)
    )
    func test_bulkEditDocuments_setStoragePath() async throws {
        let title = "Bulk Edit Set Storage Path Test \(UUID())"
        let id = try await createTestDocument(title: title)
        let storagePath = try await storagePathsRepository.createStoragePath(
            input: .init(name: "Bulk Edit Test Storage Path \(UUID())", path: "bulk-edit-test/{{ title }}"),
            server: .testValue()
        )

        try await repository.bulkEditDocuments(
            input: .init(
                documents: [id],
                method: .setStoragePath(.init(storagePath: storagePath.id))
            ),
            server: .testValue()
        )

        var documents = try await repository.getDocuments(
            input: .testValue(filterRules: [.init(ruleType: .title, value: title)]),
            server: .testValue()
        )
        #expect(documents.results.first?.storagePath == storagePath.id)

        try await repository.bulkEditDocuments(
            input: .init(
                documents: [id],
                method: .setStoragePath(.init(storagePath: nil))
            ),
            server: .testValue()
        )

        documents = try await repository.getDocuments(
            input: .testValue(filterRules: [.init(ruleType: .title, value: title)]),
            server: .testValue()
        )
        #expect(documents.results.first?.storagePath == nil)

        try await repository.bulkEditDocuments(
            input: .init(documents: [id], method: .delete),
            server: .testValue()
        )
        try await storagePathsRepository.deleteStoragePath(id: storagePath.id, server: .testValue())
    }

    private func createTempTestFile(content: String = "Test PDF content") throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent("test.pdf")

        try content.data(using: .utf8)!.write(to: tempFile)

        return tempFile
    }

    private func documentIds() async throws -> Set<Document.Id> {
        let output = try await repository.getAllDocumentIds(
            input: .testValue(),
            server: .testValue()
        )

        return Set(output.results.map(\.id))
    }

    // A comment is appended so the checksum is unique: paperless rejects a byte-identical upload as
    // a duplicate, and every PDF under `docker/data` is already seeded. Bytes after `%%EOF` are
    // ignored, so the file stays a PDF pikepdf can open — which `merge` requires and the plain-text
    // `createTempTestFile` fixture does not satisfy.
    private func createTempPdfFile() throws -> URL {
        var data = try Data(
            contentsOf: URL.projectRoot
                .appendingPathComponent("docker")
                .appendingPathComponent("data")
                .appendingPathComponent("Puky.pdf")
        )
        data.append(Data("\n% \(UUID())\n".utf8))

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(UUID()).pdf")
        try data.write(to: url)

        return url
    }

    private func createTestPdfDocument(title: String) async throws -> Document.Id {
        try await repository.createDocument(
            input: .testValue(
                createdDate: Date(),
                title: title,
                url: try createTempPdfFile()
            ),
            server: .testValue()
        )

        return try await waitForDocument(title: title)
    }

    // Found by elimination rather than by name: without `metadata_document_id` the merged
    // document's title comes from a filename paperless builds itself.
    private func waitForNewDocument(excluding existing: Set<Document.Id>) async throws -> Document.Id {
        for _ in 0 ..< 60 {
            if let id = try await documentIds().subtracting(existing).first {
                return id
            }
            try await Task.sleep(for: .seconds(1))
        }

        throw DocumentConsumptionTimedOut()
    }

    private func createTestDocument(title: String) async throws -> Document.Id {
        let tempURL = try createTempTestFile()
        try await repository.createDocument(
            input: .testValue(createdDate: Date(), title: title, url: tempURL),
            server: .testValue()
        )

        return try await waitForDocument(title: title)
    }

    private func waitForDocument(title: String) async throws -> Document.Id {
        for _ in 0 ..< 30 {
            let output = try await repository.getAllDocumentIds(
                input: .testValue(filterRules: [.init(ruleType: .title, value: title)]),
                server: .testValue()
            )
            if let id = output.results.first?.id {
                return id
            }
            try await Task.sleep(for: .seconds(1))
        }

        throw DocumentConsumptionTimedOut()
    }

    private struct DocumentConsumptionTimedOut: Error {}

    @Dependency(\.documentsRepository)
    private var repository

    @Dependency(\.tagsRepository)
    private var tagsRepository

    @Dependency(\.correspondentsRepository)
    private var correspondentsRepository

    @Dependency(\.documentTypesRepository)
    private var documentTypesRepository

    @Dependency(\.storagePathsRepository)
    private var storagePathsRepository
}
