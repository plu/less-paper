import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
public struct SaveDocumentTypeUseCase: Sendable {

    public var execute: @Sendable (
        _ id: DocumentType.Id?,
        _ input: SaveDocumentTypeInput,
        _ server: Server
    ) async throws -> SaveDocumentTypeOutput
}

extension SaveDocumentTypeUseCase: TestDependencyKey {

    public static let previewValue = Self(
        execute: { _, _, _ in .testValue() }
    )

    public static let testValue = Self(
        execute: { _, _, _ in .testValue() }
    )
}

public extension DependencyValues {
    var saveDocumentType: SaveDocumentTypeUseCase {
        get { self[SaveDocumentTypeUseCase.self] }
        set { self[SaveDocumentTypeUseCase.self] = newValue }
    }
}
