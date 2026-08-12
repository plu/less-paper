import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
public struct GetDocumentsByIdsUseCase: Sendable {

    public var execute: @Sendable (
        _ input: GetDocumentsByIdsInput,
        _ server: Server
    ) async throws -> [Document]
}

extension GetDocumentsByIdsUseCase: TestDependencyKey {

    public static let previewValue = Self(
        execute: { _, _ in [] }
    )

    public static let testValue = Self(
        execute: { _, _ in [] }
    )
}

public extension DependencyValues {

    var getDocumentsByIds: GetDocumentsByIdsUseCase {
        get { self[GetDocumentsByIdsUseCase.self] }
        set { self[GetDocumentsByIdsUseCase.self] = newValue }
    }
}
