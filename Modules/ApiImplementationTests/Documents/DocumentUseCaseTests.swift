@testable import ApiImplementation

import ApiInterface
import CustomDump
import Dependencies
import Foundation
import Testing
import TestSupport

@Suite(
    .testDependencies()
)
struct DocumentUseCaseTests {

    @Test
    func getDocuments_forwardsToRepository() async throws {
        let inputReceived = LockIsolated<GetDocumentsInput?>(nil)
        try await withDependencies {
            $0.documentsRepository.getDocuments = { input, _ in
                inputReceived.setValue(input)
                return .testValue()
            }
        } operation: {
            let output = try await GetDocumentsUseCase.liveValue.execute(
                .testValue(),
                .testValue()
            )

            expectNoDifference(inputReceived.value, .testValue())
            expectNoDifference(output, .testValue())
        }
    }

    @Test
    func getDocument_forwardsToRepository() async throws {
        let idReceived = LockIsolated<Document.Id?>(nil)
        try await withDependencies {
            $0.documentsRepository.getDocument = { id, _ in
                idReceived.setValue(id)
                return .testValue(id: 7)
            }
        } operation: {
            let document = try await GetDocumentUseCase.liveValue.execute(
                7,
                .testValue()
            )

            #expect(idReceived.value == 7)
            #expect(document.id == 7)
        }
    }

    @Test
    func getAllDocumentIds_forwardsToRepository() async throws {
        let inputReceived = LockIsolated<GetAllDocumentIdsInput?>(nil)
        try await withDependencies {
            $0.documentsRepository.getAllDocumentIds = { input, _ in
                inputReceived.setValue(input)
                return .testValue()
            }
        } operation: {
            let output = try await GetAllDocumentIdsUseCase.liveValue.execute(
                .testValue(),
                .testValue()
            )

            expectNoDifference(inputReceived.value, .testValue())
            expectNoDifference(output, .testValue())
        }
    }

    @Test
    func getDocumentsByIds_forwardsToRepository() async throws {
        let inputReceived = LockIsolated<GetDocumentsByIdsInput?>(nil)
        try await withDependencies {
            $0.documentsRepository.getDocumentsByIds = { input, _ in
                inputReceived.setValue(input)
                return [.testValue(id: 1), .testValue(id: 2)]
            }
        } operation: {
            let documents = try await GetDocumentsByIdsUseCase.liveValue.execute(
                .init(ids: [1, 2]),
                .testValue()
            )

            #expect(inputReceived.value?.ids == [1, 2])
            #expect(documents.map(\.id) == [1, 2])
        }
    }

    @Test
    func getNextArchiveSerialNumber_forwardsToRepository() async throws {
        try await withDependencies {
            $0.documentsRepository.getNextArchiveSerialNumber = { _ in 42 }
        } operation: {
            let next = try await GetNextArchiveSerialNumberUseCase.liveValue.execute(
                .testValue()
            )

            #expect(next == 42)
        }
    }

    @Test
    func getSelectionData_forwardsToRepository() async throws {
        let inputReceived = LockIsolated<GetSelectionDataInput?>(nil)
        try await withDependencies {
            $0.documentsRepository.getSelectionData = { input, _ in
                inputReceived.setValue(input)
                return .testValue()
            }
        } operation: {
            let output = try await GetSelectionDataUseCase.liveValue.execute(
                .init(documents: [1, 2]),
                .testValue()
            )

            #expect(inputReceived.value?.documents == [1, 2])
            expectNoDifference(output, .testValue())
        }
    }

    @Test
    func getDocumentMetadata_forwardsToRepository() async throws {
        let idReceived = LockIsolated<Document.Id?>(nil)
        try await withDependencies {
            $0.documentsRepository.getDocumentMetadata = { id, _ in
                idReceived.setValue(id)
                return .testValue()
            }
        } operation: {
            let metadata = try await GetDocumentMetadataUseCase.liveValue.execute(
                3,
                .testValue()
            )

            #expect(idReceived.value == 3)
            expectNoDifference(metadata, .testValue())
        }
    }

    @Test
    func downloadDocument_forwardsToRepository() async throws {
        let idReceived = LockIsolated<Document.Id?>(nil)
        let expected = try Data.testValue()
        try await withDependencies {
            $0.documentsRepository.downloadDocument = { id, _ in
                idReceived.setValue(id)
                return try .testValue()
            }
        } operation: {
            let data = try await DownloadDocumentUseCase.liveValue.execute(
                5,
                .testValue()
            )

            #expect(idReceived.value == 5)
            #expect(data == expected)
        }
    }
}
