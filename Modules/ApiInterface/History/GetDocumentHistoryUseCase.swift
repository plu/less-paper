import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
public struct GetDocumentHistoryUseCase: Sendable {

    public var execute: @Sendable (
        _ documentId: Document.Id,
        _ server: Server
    ) async throws -> [AuditLogEntry]
}

extension GetDocumentHistoryUseCase: TestDependencyKey {

    public static let previewValue = Self(
        execute: { _, _ in [.testValue()] }
    )

    public static let testValue = Self(
        execute: { _, _ in [.testValue()] }
    )
}

public extension DependencyValues {

    var getDocumentHistory: GetDocumentHistoryUseCase {
        get { self[GetDocumentHistoryUseCase.self] }
        set { self[GetDocumentHistoryUseCase.self] = newValue }
    }
}
