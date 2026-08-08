import ApiInterface
import Dependencies
import DependenciesMacros
import Foundation
import Get

@DependencyClient
struct DocumentTypesRepository: Sendable {

    var createDocumentType: @Sendable (
        _ input: SaveDocumentTypeInput,
        _ server: Server
    ) async throws -> SaveDocumentTypeOutput

    var deleteDocumentType: @Sendable (
        _ id: DocumentType.Id,
        _ server: Server
    ) async throws -> DeleteDocumentTypeOutput

    var getDocumentTypes: @Sendable (
        _ input: GetDocumentTypesInput,
        _ server: Server
    ) async throws -> GetDocumentTypesOutput

    var updateDocumentType: @Sendable (
        _ id: DocumentType.Id,
        _ input: SaveDocumentTypeInput,
        _ server: Server
    ) async throws -> SaveDocumentTypeOutput
}

extension DocumentTypesRepository: TestDependencyKey {

    static let previewValue = Self(
        createDocumentType: { _, _ in .testValue() },
        deleteDocumentType: { _, _ in },
        getDocumentTypes: { _, _ in .testValue(results: .previewValue) },
        updateDocumentType: { _, _, _ in .testValue() }
    )

    static let testValue = Self(
        createDocumentType: { _, _ in .testValue() },
        deleteDocumentType: { _, _ in },
        getDocumentTypes: { _, _ in .testValue() },
        updateDocumentType: { _, _, _ in .testValue() }
    )
}

extension DependencyValues {

    var documentTypesRepository: DocumentTypesRepository {
        get { self[DocumentTypesRepository.self] }
        set { self[DocumentTypesRepository.self] = newValue }
    }
}

extension DocumentTypesRepository: DependencyKey {
    static let liveValue = Self(
        createDocumentType: createDocumentType(input:server:),
        deleteDocumentType: deleteDocumentType(id:server:),
        getDocumentTypes: getDocumentTypes(input:server:),
        updateDocumentType: updateDocumentType(id:input:server:)
    )
}

private extension DocumentTypesRepository {

    static func createDocumentType(
        input: SaveDocumentTypeInput,
        server: Server
    ) async throws -> SaveDocumentTypeOutput {
        try await APIClient
            .client(server: server)
            .send(.init(
                path: "/api/document_types/",
                method: .post,
                body: input
            ))
            .value
    }

    static func deleteDocumentType(
        id: DocumentType.Id,
        server: Server
    ) async throws {
        try await APIClient
            .client(server: server)
            .send(.init(
                path: "/api/document_types/\(id)/",
                method: .delete
            ))
            .value
    }

    static func getDocumentTypes(
        input: GetDocumentTypesInput,
        server: Server
    ) async throws -> GetDocumentTypesOutput {
        try await APIClient
            .client(server: server)
            .send(.init(input: input))
            .value
    }

    static func updateDocumentType(
        id: DocumentType.Id,
        input: SaveDocumentTypeInput,
        server: Server
    ) async throws -> SaveDocumentTypeOutput {
        try await APIClient
            .client(server: server)
            .send(.init(
                path: "/api/document_types/\(id)/",
                method: .patch,
                body: input
            ))
            .value
    }
}

private extension Request where Response == GetDocumentTypesOutput {

    init(input: GetDocumentTypesInput) {
        if let url = input.url {
            self.init(
                url: url,
                method: .get
            )
            return
        }
        self.init(
            path: "/api/document_types/",
            method: .get
        )
    }
}
