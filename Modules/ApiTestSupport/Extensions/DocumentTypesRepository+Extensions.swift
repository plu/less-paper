@testable import ApiImplementation

import ApiInterface

extension DocumentTypesRepository {

    func deleteAll() async throws {
        let documentTypes = try await getDocumentTypes(
            input: .testValue(),
            server: .testValue()
        ).results.map(\.id)
        for documentType in documentTypes {
            try await deleteDocumentType(
                id: documentType,
                server: .testValue()
            )
        }
    }
}
