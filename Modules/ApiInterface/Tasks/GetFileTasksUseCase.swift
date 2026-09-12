import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
public struct GetFileTasksUseCase: Sendable {

    public var execute: @Sendable (
        _ server: Server,
        _ status: FileTaskStatus,
        _ page: Int
    ) async throws -> FileTaskPage
}

extension GetFileTasksUseCase: TestDependencyKey {

    public static let previewValue = Self(
        execute: { _, _, _ in .testValue() }
    )

    public static let testValue = Self(
        execute: { _, _, _ in .testValue() }
    )
}

public extension DependencyValues {

    var getFileTasks: GetFileTasksUseCase {
        get { self[GetFileTasksUseCase.self] }
        set { self[GetFileTasksUseCase.self] = newValue }
    }
}
