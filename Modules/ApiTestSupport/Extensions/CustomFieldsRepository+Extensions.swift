@testable import ApiImplementation

import ApiInterface

extension CustomFieldsRepository {

    func deleteAll() async throws {
        let customFields = try await getCustomFields(
            input: .testValue(),
            server: .testValue()
        ).results.map(\.id)
        for customField in customFields {
            try await deleteCustomField(
                id: customField,
                server: .testValue()
            )
        }
    }
}
