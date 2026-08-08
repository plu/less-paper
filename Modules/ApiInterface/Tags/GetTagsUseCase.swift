import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
public struct GetTagsUseCase: Sendable {

    public var execute: @Sendable (
        _ server: Server
    ) async throws -> [Tag]
}

extension GetTagsUseCase: TestDependencyKey {

    public static let previewValue = Self(
        execute: { _ in [.testValue()] }
    )

    public static let testValue = Self(
        execute: { _ in [.testValue()] }
    )
}

public extension DependencyValues {
    var getTags: GetTagsUseCase {
        get { self[GetTagsUseCase.self] }
        set { self[GetTagsUseCase.self] = newValue }
    }
}
