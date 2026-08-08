import ApiInterface
import Dependencies
import DependenciesMacros
import Foundation
import Get

@DependencyClient
struct StatisticsRepository: Sendable {

    var getStatistics: @Sendable (
        _ input: GetStatisticsInput,
        _ server: Server
    ) async throws -> GetStatisticsOutput
}

extension StatisticsRepository: TestDependencyKey {

    static let previewValue = Self(
        getStatistics: { _, _ in .testValue() }
    )

    static let testValue = Self(
        getStatistics: { _, _ in .testValue() }
    )
}

extension DependencyValues {

    var statisticsRepository: StatisticsRepository {
        get { self[StatisticsRepository.self] }
        set { self[StatisticsRepository.self] = newValue }
    }
}

extension StatisticsRepository: DependencyKey {
    static let liveValue = Self(
        getStatistics: getStatistics(input:server:)
    )
}

private extension StatisticsRepository {

    static func getStatistics(
        input: GetStatisticsInput,
        server: Server
    ) async throws -> GetStatisticsOutput {
        try await APIClient
            .client(server: server)
            .send(.init(input: input))
            .value
    }
}

private extension Request where Response == GetStatisticsOutput {

    init(input: GetStatisticsInput) {
        self.init(
            path: "/api/statistics/",
            method: .get
        )
    }
}
