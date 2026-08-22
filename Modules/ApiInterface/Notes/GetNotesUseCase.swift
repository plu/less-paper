import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
public struct GetNotesUseCase: Sendable {

    public var execute: @Sendable (
        _ documentId: Document.Id,
        _ server: Server
    ) async throws -> [Note]
}

extension GetNotesUseCase: TestDependencyKey {

    public static let previewValue = Self(
        execute: { _, _ in [.testValue()] }
    )

    public static let testValue = Self(
        execute: { _, _ in [.testValue()] }
    )
}

public extension DependencyValues {

    var getNotes: GetNotesUseCase {
        get { self[GetNotesUseCase.self] }
        set { self[GetNotesUseCase.self] = newValue }
    }
}
