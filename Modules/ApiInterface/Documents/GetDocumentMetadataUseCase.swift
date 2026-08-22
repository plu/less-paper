import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
public struct GetDocumentMetadataUseCase: Sendable {

    public var execute: @Sendable (
        _ id: Document.Id,
        _ server: Server
    ) async throws -> DocumentMetadata
}

extension GetDocumentMetadataUseCase: TestDependencyKey {

    public static let previewValue = Self(
        execute: { _, _ in .testValue() }
    )

    public static let testValue = Self(
        execute: { _, _ in .testValue() }
    )
}

public extension DependencyValues {

    var getDocumentMetadata: GetDocumentMetadataUseCase {
        get { self[GetDocumentMetadataUseCase.self] }
        set { self[GetDocumentMetadataUseCase.self] = newValue }
    }
}
