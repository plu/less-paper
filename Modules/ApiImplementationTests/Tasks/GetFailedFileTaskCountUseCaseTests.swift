@testable import ApiImplementation

import ApiInterface
import Dependencies
import Foundation
import SwiftSharing
import Testing
import TestSupport

@Suite(
    .dependencies()
)
struct GetFailedFileTaskCountUseCaseTests {

    @Test
    func execute_onVersion10_readsTheCountFromTheServer() async throws {
        let server = Server.testValue()
        @Shared(.apiVersion(server))
        var apiVersion: Int?
        $apiVersion.withLock { $0 = 10 }

        try await withDependencies {
            $0.fileTaskRepository.getFailedFileTaskCountV10 = { _ in 3 }
        } operation: {
            let count = try await GetFailedFileTaskCountUseCase.liveValue.execute(server: server)

            #expect(count == 3)
        }
    }

    // Only unacknowledged failures count: a dismissed failure is one the user has dealt with, and
    // the badge is there to ask for something.
    @Test
    func execute_onVersion9_countsUnacknowledgedFailedConsumeTasks() async throws {
        let server = Server.testValue()
        @Shared(.apiVersion(server))
        var apiVersion: Int?
        $apiVersion.withLock { $0 = 9 }

        try await withDependencies {
            $0.fileTaskRepository.getFileTasksV9 = { _ in
                [
                    .testValue(id: 1, status: "FAILURE", taskName: "consume_file"),
                    .testValue(id: 2, status: "FAILURE", taskName: "consume_file"),
                    .testValue(acknowledged: true, id: 3, status: "FAILURE", taskName: "consume_file"),
                    .testValue(id: 4, status: "SUCCESS", taskName: "consume_file"),
                    .testValue(id: 5, status: "FAILURE", taskName: "train_classifier")
                ]
            }
        } operation: {
            let count = try await GetFailedFileTaskCountUseCase.liveValue.execute(server: server)

            #expect(count == 2)
        }
    }

    // The use case writes the badge's shared key itself, the way GetStatisticsUseCase writes
    // inboxDocumentCount, so that no caller has to remember to.
    @Test
    func execute_writesTheSharedCount() async throws {
        let server = Server.testValue()
        @Shared(.apiVersion(server))
        var apiVersion: Int?
        $apiVersion.withLock { $0 = 10 }

        @Shared(.failedFileTaskCount(server))
        var failedFileTaskCount: Int

        #expect(failedFileTaskCount == 0)

        try await withDependencies {
            $0.fileTaskRepository.getFailedFileTaskCountV10 = { _ in 7 }
        } operation: {
            _ = try await GetFailedFileTaskCountUseCase.liveValue.execute(server: server)
        }

        #expect(failedFileTaskCount == 7)
    }

    // A server that cannot answer must not blank the badge: the last known number is better than a
    // zero that means "we could not ask". The swallowing happens in the free function, so that is
    // what this drives. The repository is stubbed, not the use case, because the use case is what
    // writes the shared key: stubbing it instead would leave nothing to write and prove nothing.
    @Test
    func refresh_leavesTheCountAloneOnFailure() async throws {
        let server = Server.testValue()
        @Shared(.apiVersion(server))
        var apiVersion: Int?
        $apiVersion.withLock { $0 = 10 }

        @Shared(.failedFileTaskCount(server))
        var failedFileTaskCount: Int
        $failedFileTaskCount.withLock { $0 = 4 }

        await withDependencies {
            $0.fileTaskRepository.getFailedFileTaskCountV10 = { _ in throw ApiError.testValue() }
            $0.getFailedFileTaskCount = .liveValue
        } operation: {
            await refreshFailedFileTaskCount(server: server)
        }

        #expect(failedFileTaskCount == 4)
    }
}
