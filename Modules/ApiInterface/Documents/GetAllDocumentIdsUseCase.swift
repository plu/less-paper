import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
public struct GetAllDocumentIdsUseCase: Sendable {

    public var execute: @Sendable (
        _ input: GetAllDocumentIdsInput,
        _ server: Server
    ) async throws -> GetAllDocumentIdsOutput
}

extension GetAllDocumentIdsUseCase: TestDependencyKey {

    public static let previewValue = Self(
        execute: { _, _ in .testValue() }
    )

    public static let testValue = Self(
        execute: { _, _ in .testValue() }
    )
}

public extension DependencyValues {
    var getAllDocumentIds: GetAllDocumentIdsUseCase {
        get { self[GetAllDocumentIdsUseCase.self] }
        set { self[GetAllDocumentIdsUseCase.self] = newValue }
    }
}
