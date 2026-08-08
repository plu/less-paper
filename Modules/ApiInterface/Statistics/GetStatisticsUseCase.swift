import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
public struct GetStatisticsUseCase: Sendable {

    public var execute: @Sendable (
        _ server: Server
    ) async throws -> GetStatisticsOutput
}

extension GetStatisticsUseCase: TestDependencyKey {

    public static let previewValue = Self(
        execute: { _ in .testValue() }
    )

    public static let testValue = Self(
        execute: { _ in .testValue() }
    )
}

public extension DependencyValues {

    var getStatistics: GetStatisticsUseCase {
        get { self[GetStatisticsUseCase.self] }
        set { self[GetStatisticsUseCase.self] = newValue }
    }
}
