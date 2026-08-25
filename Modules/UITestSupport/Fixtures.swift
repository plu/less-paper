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
