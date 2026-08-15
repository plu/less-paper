@testable import ApiImplementation

import ApiInterface
import Dependencies
import Foundation
import IdentifiedCollections
import SwiftSharing
import Testing

/**
 * Every mutation that can change the number of documents in the inbox must refresh the cached
 * statistics, otherwise the Inbox tab badge keeps showing the count from the last refresh.
 *
 * These tests drive the real `liveValue` of each use case with a stubbed repository, so they fail
 * if the refresh is dropped from any one of them.
 */
@MainActor
@Suite
struct DocumentStatisticsRefreshTests {

    @Test
    func bulkEditDocuments_refreshesStatistics() async throws {
        let serversReceived = LockIsolated<[Server]>([])

        try await withDependencies {
            $0.documentsRepository.bulkEditDocuments = { _, _ in }
            $0.getStatistics.execute = { server in
                serversReceived.withValue { $0.append(server) }
                return .testValue()
            }
        } operation: {
            try await BulkEditDocumentsUseCase.liveValue.execute(
                .testValue(),
                .testValue()
            )
        }

        #expect(serversReceived.value == [.testValue()])
    }

    @Test
    func createDocument_refreshesStatistics() async throws {
        let serversReceived = LockIsolated<[Server]>([])

        try await withDependencies {
            $0.documentsRepository.createDocument = { _, _ in }
            $0.getStatistics.execute = { server in
                serversReceived.withValue { $0.append(server) }
                return .testValue()
            }
        } operation: {
            try await CreateDocumentUseCase.liveValue.execute(
                .testValue(),
                .testValue()
            )
        }

        #expect(serversReceived.value == [.testValue()])
    }

    @Test
    func deleteDocuments_refreshesStatistics() async throws {
        let serversReceived = LockIsolated<[Server]>([])

        try await withDependencies {
            $0.documentsRepository.bulkEditDocuments = { _, _ in }
            $0.getStatistics.execute = { server in
                serversReceived.withValue { $0.append(server) }
                return .testValue()
            }
        } operation: {
            try await DeleteDocumentsUseCase.liveValue.execute(
                [1],
                .testValue()
            )
        }

        #expect(serversReceived.value == [.testValue()])
    }

    @Test
    func updateDocument_refreshesStatistics() async throws {
        let serversReceived = LockIsolated<[Server]>([])

        try await withDependencies {
            $0.documentsRepository.updateDocument = { _, _, _ in .testValue() }
            $0.getStatistics.execute = { server in
                serversReceived.withValue { $0.append(server) }
                return .testValue()
            }
        } operation: {
            _ = try await UpdateDocumentUseCase.liveValue.execute(
                1,
                .testValue(),
                .testValue()
            )
        }

        #expect(serversReceived.value == [.testValue()])
    }

    /// The mutation has already succeeded by the time the refresh runs, so a failure to refresh
    /// must not fail the mutation — the badge simply stays stale until the next refresh.
    @Test
    func refreshFailure_doesNotFailTheMutation() async throws {
        try await withDependencies {
            $0.documentsRepository.bulkEditDocuments = { _, _ in }
            $0.getStatistics.execute = { _ in throw ApiError.testValue() }
        } operation: {
            try await BulkEditDocumentsUseCase.liveValue.execute(
                .testValue(),
                .testValue()
            )
        }
    }
}
