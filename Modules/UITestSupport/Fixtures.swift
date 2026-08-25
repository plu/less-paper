@testable import ApiImplementation

import ApiInterface
import Dependencies
import Foundation

// Custom fields are global in paperless-ngx: they carry no owner, so a per-test user cannot isolate
// them. Every fixture here is namespaced by name and deleted by the test that made it.
public enum Fixtures {

    public static func createCustomField(
        name: String,
        dataType: CustomFieldDataType
    ) async throws -> CustomField.Id {
        try await withAdminDependencies {
            @Dependency(\.customFieldsRepository)
            var customFieldsRepository

            return try await customFieldsRepository.createCustomField(
                input: SaveCustomFieldInput(
                    dataType: dataType,
                    name: name
                ),
                server: .testValue()
            ).id
        }
    }

    public static func deleteCustomField(
        id: CustomField.Id
    ) async throws {
        try await withAdminDependencies {
            @Dependency(\.customFieldsRepository)
            var customFieldsRepository

            _ = try await customFieldsRepository.deleteCustomField(
                id: id,
                server: .testValue()
            )
        }
    }

    // Uploaded as the test user, not as admin: paperless owns a document to whoever created it, and
    // an admin-owned one would be invisible to the user the journey runs as.
    //
    // Consumption is asynchronous — the document only gets an id once the consumer has finished, in
    // about three seconds — so this polls for it rather than sleeping a guessed interval.
    public static func uploadDocument(
        titled title: String,
        token: String
    ) async throws -> Document.Id {
        try await withUserDependencies(token: token) {
            @Dependency(\.documentsRepository)
            var documentsRepository

            try await documentsRepository.createDocument(
                input: CreateDocumentInput(
                    archiveSerialNumber: nil,
                    correspondent: nil,
                    createdDate: Date(),
                    documentType: nil,
                    storagePath: nil,
                    tags: [],
                    title: title,
                    url: .projectRoot.appending(path: "docker/data/Sonos One.pdf")
                ),
                server: .testValue()
            )

            for _ in 0 ..< 60 {
                let documents = try await documentsRepository.getDocuments(
                    input: GetDocumentsInput(),
                    server: .testValue()
                ).results

                if let document = documents.first(where: { $0.title == title }) {
                    return document.id
                }
                try await Task.sleep(for: .milliseconds(500))
            }

            throw ConsumptionTimeout(title: title)
        }
    }

    public static func deleteDocument(
        id: Document.Id,
        token: String
    ) async throws {
        try await withUserDependencies(token: token) {
            @Dependency(\.documentsRepository)
            var documentsRepository

            _ = try await documentsRepository.bulkEditDocuments(
                input: BulkEditDocumentsInput(
                    documents: [id],
                    method: .delete
                ),
                server: .testValue()
            )
        }
    }

    struct ConsumptionTimeout: Error {
        let title: String
    }

    // Deletes as admin: a superuser can remove an object the per-test user owns, and the test knows
    // the tag only by the name it typed into the form.
    public static func deleteTag(named name: String) async throws {
        try await withAdminDependencies {
            @Dependency(\.tagsRepository)
            var tagsRepository

            let tags = try await tagsRepository.getTags(
                input: GetTagsInput(),
                server: .testValue()
            ).results

            guard let tag = tags.first(where: { $0.name == name }) else {
                return
            }

            _ = try await tagsRepository.deleteTag(
                id: tag.id,
                server: .testValue()
            )
        }
    }

    // A crashed run leaves its namespaced fields behind, and unlike users they are visible to every
    // later test's field list.
    public static func sweepOrphanedCustomFields() async throws {
        try await withAdminDependencies {
            @Dependency(\.customFieldsRepository)
            var customFieldsRepository

            let fields = try await customFieldsRepository.getCustomFields(
                input: .testValue(),
                server: .testValue()
            ).results

            for field in fields where field.name.hasPrefix("uit-") {
                _ = try? await customFieldsRepository.deleteCustomField(
                    id: field.id,
                    server: .testValue()
                )
            }
        }
    }
}
