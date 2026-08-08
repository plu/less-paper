import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
public struct CreateDocumentUseCase: Sendable {

    public var execute: @Sendable (
        _ input: CreateDocumentInput,
        _ server: Server
    ) async throws -> Void
}

extension CreateDocumentUseCase: TestDependencyKey {

    public static let previewValue = Self(
        execute: { _, _ in }
    )

    public static let testValue = Self(
        execute: { _, _ in }
    )
}

public extension DependencyValues {

    var createDocument: CreateDocumentUseCase {
        get { self[CreateDocumentUseCase.self] }
        set { self[CreateDocumentUseCase.self] = newValue }
    }
}
