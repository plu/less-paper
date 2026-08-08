import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
public struct UpdateDocumentUseCase: Sendable {

    public var execute: @Sendable (
        _ id: Document.Id,
        _ input: UpdateDocumentInput,
        _ server: Server
    ) async throws -> Document
}

extension UpdateDocumentUseCase: TestDependencyKey {

    public static let previewValue = Self(
        execute: { _, _, _ in .testValue() }
    )

    public static let testValue = Self(
        execute: { _, _, _ in .testValue() }
    )
}

public extension DependencyValues {

    var updateDocument: UpdateDocumentUseCase {
        get { self[UpdateDocumentUseCase.self] }
        set { self[UpdateDocumentUseCase.self] = newValue }
    }
}
