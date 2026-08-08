import ApiInterface
import Dependencies
import DependenciesMacros
import Foundation
import Get
import MultipartFormDataKit

@DependencyClient
struct DocumentsRepository: Sendable {

    var bulkEditDocuments: @Sendable (
        _ input: BulkEditDocumentsInput,
        _ server: Server
    ) async throws -> Void

    var createDocument: @Sendable (
        _ input: CreateDocumentInput,
        _ server: Server
    ) async throws -> Void

    var downloadDocument: @Sendable (
        _ id: Document.Id,
        _ server: Server
    ) async throws -> Data

    var getAllDocumentIds: @Sendable (
        _ input: GetAllDocumentIdsInput,
        _ server: Server
    ) async throws -> GetAllDocumentIdsOutput

    var getDocuments: @Sendable (
        _ input: GetDocumentsInput,
        _ server: Server
    ) async throws -> GetDocumentsOutput

    var getNextArchiveSerialNumber: @Sendable (
        _ server: Server
    ) async throws -> Int

    var updateDocument: @Sendable (
        _ id: Document.Id,
        _ input: UpdateDocumentInput,
        _ server: Server
    ) async throws -> Document
}

extension DocumentsRepository: TestDependencyKey {

    static let previewValue = Self(
        bulkEditDocuments: { _, _ in },
        createDocument: { _, _ in },
        downloadDocument: { _, _ in try .testValue() },
        getAllDocumentIds: { _, _ in .testValue() },
        getDocuments: { _, _ in .testValue() },
        getNextArchiveSerialNumber: { _ in 1 },
        updateDocument: { _, _, _ in .testValue() }
    )

    static let testValue = Self(
        bulkEditDocuments: { _, _ in },
        createDocument: { _, _ in },
        downloadDocument: { _, _ in try .testValue() },
        getAllDocumentIds: { _, _ in .testValue() },
        getDocuments: { _, _ in .testValue() },
        getNextArchiveSerialNumber: { _ in 1 },
        updateDocument: { _, _, _ in .testValue() }
    )
}

extension DependencyValues {

    var documentsRepository: DocumentsRepository {
        get { self[DocumentsRepository.self] }
        set { self[DocumentsRepository.self] = newValue }
    }
}

extension DocumentsRepository: DependencyKey {
    static let liveValue = Self(
        bulkEditDocuments: bulkEditDocuments(input:server:),
        createDocument: createDocument(input:server:),
        downloadDocument: downloadDocument(id:server:),
        getAllDocumentIds: getAllDocumentIds(input:server:),
        getDocuments: getDocuments(input:server:),
        getNextArchiveSerialNumber: getNextArchiveSerialNumber(server:),
        updateDocument: updateDocument(id:input:server:)
    )
}

private extension DocumentsRepository {

    static func bulkEditDocuments(
        input: BulkEditDocumentsInput,
        server: Server
    ) async throws {
        try await APIClient
            .client(server: server)
            .send(.init(
                path: "/api/documents/bulk_edit/",
                method: .post,
                body: input
            ))
            .value
    }

    static func createDocument(
        input: CreateDocumentInput,
        server: Server
    ) async throws {
        try await APIClient
            .client(server: server)
            .send(.init(
                path: "/api/documents/post_document/",
                method: .post
            ), configure: {
                let formData = try input.formData
                $0.setValue(formData.contentType, forHTTPHeaderField: "Content-Type")
                $0.httpBody = formData.body
            })
            .value
    }

    static func downloadDocument(
        id: Document.Id,
        server: Server
    ) async throws -> Data {
        try await APIClient
            .client(server: server)
            .send(.init(
                path: "/api/documents/\(id)/download/",
                method: .get
            ))
            .value
    }

    static func getAllDocumentIds(
        input: GetAllDocumentIdsInput,
        server: Server
    ) async throws -> GetAllDocumentIdsOutput {
        try await APIClient
            .client(server: server)
            .send(.init(input: input))
            .value
    }

    static func getDocuments(
        input: GetDocumentsInput,
        server: Server
    ) async throws -> GetDocumentsOutput {
        try await APIClient
            .client(server: server)
            .send(.init(input: input))
            .value
    }

    static func getNextArchiveSerialNumber(
        server: Server
    ) async throws -> Int {
        try await APIClient
            .client(server: server)
            .send(.init(
                path: "/api/documents/next_asn/",
                method: .get
            ))
            .value
    }

    static func updateDocument(
        id: Document.Id,
        input: UpdateDocumentInput,
        server: Server
    ) async throws -> Document {
        try await APIClient
            .client(server: server)
            .send(.init(
                path: "/api/documents/\(id)/",
                method: .patch,
                body: input
            ))
            .value
    }
}

private extension Request where Response == GetDocumentsOutput {

    init(input: GetDocumentsInput) {
        if let url = input.url {
            self.init(
                url: url,
                method: .get
            )
            return
        }
        self.init(
            path: "/api/documents/",
            method: .get,
            query: [
                "ordering": [input.sortDirection.rawValue, input.sortField.rawValue].joined(),
                "page": "1",
                "page_size": "100",
                "truncate_content": "true",
            ] + input.filterRules.queryDictionary.map { ($0, "\($1)") }
        )
    }
}

private extension Request where Response == GetAllDocumentIdsOutput {
    init(input: GetAllDocumentIdsInput) {
        self.init(
            path: "/api/documents/",
            method: .get,
            query: [
                "fields": "id",
                "page": "1",
                "page_size": "1000000",
                "truncate_content": "true",
            ] + input.filterRules.queryDictionary.map { ($0, "\($1)") }
        )
    }
}
