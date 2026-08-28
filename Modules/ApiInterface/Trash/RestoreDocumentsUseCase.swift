import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
public struct RestoreDocumentsUseCase: Sendable {

    public var execute: @Sendable (
        _ ids: [Document.Id],
        _ server: Server
    ) async throws -> Void
}

extension RestoreDocumentsUseCase: TestDependencyKey {

    public static let previewValue = Self(execute: { _, _ in })

    public static let testValue = Self(execute: { _, _ in })
}

public extension DependencyValues {

    var restoreDocuments: RestoreDocumentsUseCase {
        get { self[RestoreDocumentsUseCase.self] }
        set { self[RestoreDocumentsUseCase.self] = newValue }
    }
}
