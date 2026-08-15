@testable import ApiImplementation

import ApiInterface
import Dependencies
import Foundation
import IdentifiedCollections
import SwiftSharing
import Testing

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
