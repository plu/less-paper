import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
public struct GetDocumentsUseCase: Sendable {

    public var execute: @Sendable (
        _ input: GetDocumentsInput,
        _ server: Server
    ) async throws -> GetDocumentsOutput
}

extension GetDocumentsUseCase: TestDependencyKey {

    public static let previewValue = Self(
        execute: { _, _ in .testValue() }
    )

    public static let testValue = Self(
        execute: { _, _ in .testValue() }
    )
}

public extension DependencyValues {
    var getDocuments: GetDocumentsUseCase {
        get { self[GetDocumentsUseCase.self] }
        set { self[GetDocumentsUseCase.self] = newValue }
    }
}
