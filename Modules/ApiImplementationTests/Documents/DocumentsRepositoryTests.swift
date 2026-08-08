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
        let input = CreateDocumentInput.testValue(
            createdDate: Date(),
            url: URL.projectRoot
                .appendingPathComponent("docker")
                .appendingPathComponent("data")
                .appendingPathComponent("Puky.pdf")
        )

        try await repository.createDocument(
            input: input,
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

    private func createTempTestFile(content: String = "Test PDF content") throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent("test.pdf")

        try content.data(using: .utf8)!.write(to: tempFile)

        return tempFile
    }

    @Dependency(\.documentsRepository)
    private var repository
}
