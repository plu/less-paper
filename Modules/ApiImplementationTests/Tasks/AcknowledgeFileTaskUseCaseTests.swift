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
struct AcknowledgeFileTaskUseCaseTests {

    @Test
    func execute_onVersion10_usesTheModernPath() async throws {
        let server = Server.testValue()
        @Shared(.apiVersion(server))
        var apiVersion: Int?
        $apiVersion.withLock { $0 = 10 }

        let modern = LockIsolated<FileTask.Id?>(nil)

        try await withDependencies {
            $0.fileTaskRepository.acknowledgeFileTask = { id, _ in modern.setValue(id) }
        } operation: {
            try await AcknowledgeFileTaskUseCase.liveValue.execute(id: 7, server: server)
        }

        #expect(modern.value == 7)
    }

    // API 8 is the supported floor. Measured against 2.15.3: the legacy `/api/acknowledge_tasks/`
    // answers 403 there, so the modern path is the only one that has ever worked here too.
    @Test
    func execute_onVersion8_usesTheModernPath() async throws {
        let server = Server.testValue()
        @Shared(.apiVersion(server))
        var apiVersion: Int?
        $apiVersion.withLock { $0 = 8 }

        let modern = LockIsolated<FileTask.Id?>(nil)

        try await withDependencies {
            $0.fileTaskRepository.acknowledgeFileTask = { id, _ in modern.setValue(id) }
        } operation: {
            try await AcknowledgeFileTaskUseCase.liveValue.execute(id: 7, server: server)
        }

        #expect(modern.value == 7)
    }

    @Test
    func execute_withNoNegotiatedVersion_usesTheModernPath() async throws {
        let server = Server.testValue()

        let modern = LockIsolated<FileTask.Id?>(nil)

        try await withDependencies {
            $0.fileTaskRepository.acknowledgeFileTask = { id, _ in modern.setValue(id) }
        } operation: {
            try await AcknowledgeFileTaskUseCase.liveValue.execute(id: 7, server: server)
        }

        #expect(modern.value == 7)
    }

    // The count is re-read from the server rather than decremented locally, the same rule
    // GetFailedFileTaskCountUseCase's own tests drive from the other side.
    @Test
    func execute_onSuccess_refreshesTheFailedCountFromTheServer() async throws {
        let server = Server.testValue()
        @Shared(.apiVersion(server))
        var apiVersion: Int?
        $apiVersion.withLock { $0 = 10 }

        @Shared(.failedFileTaskCount(server))
        var failedFileTaskCount: Int
        $failedFileTaskCount.withLock { $0 = 4 }

        try await withDependencies {
            $0.fileTaskRepository.acknowledgeFileTask = { _, _ in }
            $0.fileTaskRepository.getFailedFileTaskCountV10 = { _ in 3 }
            $0.getFailedFileTaskCount = .liveValue
        } operation: {
            try await AcknowledgeFileTaskUseCase.liveValue.execute(id: 7, server: server)
        }

        #expect(failedFileTaskCount == 3)
    }
}
