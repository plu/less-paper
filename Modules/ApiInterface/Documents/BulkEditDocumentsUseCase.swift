import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
public struct BulkEditDocumentsUseCase: Sendable {

    public var execute: @Sendable (
        _ input: BulkEditDocumentsInput,
        _ server: Server
    ) async throws -> Void
}

extension BulkEditDocumentsUseCase: TestDependencyKey {

    public static let previewValue = Self(
        execute: { _, _ in }
    )

    public static let testValue = Self(
        execute: { _, _ in }
    )
}

public extension DependencyValues {

    var bulkEditDocuments: BulkEditDocumentsUseCase {
        get { self[BulkEditDocumentsUseCase.self] }
        set { self[BulkEditDocumentsUseCase.self] = newValue }
    }
}
