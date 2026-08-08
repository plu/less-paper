@testable import ApiImplementation

import ApiInterface
import Dependencies
import Foundation
import Testing

@Suite
struct GetStatisticsUseCaseTests {

    @Test
    func execute() async throws {
        try await withDependencies {
            $0.statisticsRepository.getStatistics = { _, _ in
                .testValue()
            }
        } operation: {
            let useCase = GetStatisticsUseCase.liveValue

            let statistics = try await useCase.execute(
                server: .testValue()
            )

            #expect(statistics == .testValue())
        }
    }
}
