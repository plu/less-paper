import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
public struct AcknowledgeFileTaskUseCase: Sendable {

    public var execute: @Sendable (
        _ id: FileTask.Id,
        _ server: Server
    ) async throws -> Void
}

extension AcknowledgeFileTaskUseCase: TestDependencyKey {

    public static let previewValue = Self(
        execute: { _, _ in }
    )

    public static let testValue = Self(
        execute: { _, _ in }
    )
}

public extension DependencyValues {

    var acknowledgeFileTask: AcknowledgeFileTaskUseCase {
        get { self[AcknowledgeFileTaskUseCase.self] }
        set { self[AcknowledgeFileTaskUseCase.self] = newValue }
    }
}
