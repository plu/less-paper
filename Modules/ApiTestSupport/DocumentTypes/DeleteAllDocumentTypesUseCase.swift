import ApiInterface
import Dependencies
import DependenciesMacros
import Foundation
import IdentifiedCollections

extension DeleteAllDocumentTypesUseCase: @retroactive DependencyKey {
    public static let liveValue = Self(
        execute: execute(server:)
    )
}

private extension DeleteAllDocumentTypesUseCase {

    static func execute(
        server: Server
    ) async throws {
        @Dependency(\.getDocumentTypes.execute)
        var getDocumentTypes

        @Dependency(\.deleteDocumentType.execute)
        var deleteDocumentType

        let documentTypes = try await getDocumentTypes(server)

        for documentType in documentTypes {
            try await deleteDocumentType(documentType.id, server)
        }
    }
}
