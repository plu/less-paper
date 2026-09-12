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
    func execute_onVersion10_usesTheTasksSubresource() async throws {
        let server = Server.testValue()
        @Shared(.apiVersion(server))
        var apiVersion: Int?
        $apiVersion.withLock { $0 = 10 }

        let modern = LockIsolated<FileTask.Id?>(nil)
        let legacy = LockIsolated(false)

        try await withDependencies {
            $0.fileTaskRepository.acknowledgeFileTask = { id, _ in modern.setValue(id) }
            $0.fileTaskRepository.acknowledgeFileTaskLegacy = { _, _ in legacy.setValue(true) }
        } operation: {
            try await AcknowledgeFileTaskUseCase.liveValue.execute(id: 7, server: server)
        }

        #expect(modern.value == 7)
        #expect(!legacy.value)
    }

    // 3.0.5 moved this endpoint. Older servers only have the top-level one, and calling the new path
    // there falls through to a non-DRF view that answers 403.
    @Test
    func execute_onVersion9_usesTheLegacyPath() async throws {
        let server = Server.testValue()
        @Shared(.apiVersion(server))
        var apiVersion: Int?
        $apiVersion.withLock { $0 = 9 }

        let modern = LockIsolated(false)
        let legacy = LockIsolated<FileTask.Id?>(nil)

        try await withDependencies {
            $0.fileTaskRepository.acknowledgeFileTask = { _, _ in modern.setValue(true) }
            $0.fileTaskRepository.acknowledgeFileTaskLegacy = { id, _ in legacy.setValue(id) }
        } operation: {
            try await AcknowledgeFileTaskUseCase.liveValue.execute(id: 7, server: server)
        }

        #expect(legacy.value == 7)
        #expect(!modern.value)
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
