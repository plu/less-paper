import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
public struct GetDocumentUseCase: Sendable {

    public var execute: @Sendable (
        _ id: Document.Id,
        _ server: Server
    ) async throws -> Document
}

extension GetDocumentUseCase: TestDependencyKey {

    public static let previewValue = Self(
        execute: { _, _ in .testValue() }
    )

    public static let testValue = Self(
        execute: { _, _ in .testValue() }
    )
}

public extension DependencyValues {

    var getDocument: GetDocumentUseCase {
        get { self[GetDocumentUseCase.self] }
        set { self[GetDocumentUseCase.self] = newValue }
    }
}
