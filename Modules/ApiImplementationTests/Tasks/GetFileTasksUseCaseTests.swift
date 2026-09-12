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
struct GetFileTasksUseCaseTests {

    @Test
    func execute_onVersion10_asksTheServerToFilterAndPage() async throws {
        let server = Server.testValue()
        @Shared(.apiVersion(server))
        var apiVersion: Int?
        $apiVersion.withLock { $0 = 10 }

        let askedFor = LockIsolated<(FileTaskStatus, Int)?>(nil)

        try await withDependencies {
            $0.fileTaskRepository.getFileTasksV10 = { status, page, _ in
                askedFor.setValue((status, page))
                return .init(
                    count: 43,
                    next: .testValue(string: "http://host/api/tasks/?page=2"),
                    results: [.testValue(id: 1)]
                )
            }
        } operation: {
            let page = try await GetFileTasksUseCase.liveValue.execute(
                server: server,
                status: .failed,
                page: 1
            )

            #expect(page.tasks.map(\.id) == [1])
            #expect(page.nextPage == 2)
        }

        #expect(askedFor.value?.0 == .failed)
        #expect(askedFor.value?.1 == 1)
    }

    @Test
    func execute_onVersion10_reportsNoNextPageOnTheLastOne() async throws {
        let server = Server.testValue()
        @Shared(.apiVersion(server))
        var apiVersion: Int?
        $apiVersion.withLock { $0 = 10 }

        try await withDependencies {
            $0.fileTaskRepository.getFileTasksV10 = { _, _, _ in
                .init(count: 1, next: nil, results: [.testValue(id: 1)])
            }
        } operation: {
            let page = try await GetFileTasksUseCase.liveValue.execute(
                server: server,
                status: .complete,
                page: 1
            )

            #expect(page.nextPage == nil)
        }
    }

    // An old server cannot filter or page, so the use case does both jobs itself: consume tasks
    // only, this status only, not already dismissed, newest first, and nothing left to fetch.
    @Test
    func execute_onVersion9_filtersSortsAndClaimsNoNextPage() async throws {
        let server = Server.testValue()
        @Shared(.apiVersion(server))
        var apiVersion: Int?
        $apiVersion.withLock { $0 = 9 }

        let v10Requested = LockIsolated(false)

        try await withDependencies {
            $0.fileTaskRepository.getFileTasksV10 = { _, _, _ in
                v10Requested.setValue(true)
                return .init()
            }
            $0.fileTaskRepository.getFileTasksV9 = { _ in
                [
                    .testValue(dateCreated: .testValue(), id: 1, status: "FAILURE", taskName: "consume_file"),
                    .testValue(dateCreated: .testValue().addingTimeInterval(60), id: 2, status: "FAILURE", taskName: "consume_file"),
                    .testValue(id: 3, status: "FAILURE", taskName: "train_classifier"),
                    .testValue(id: 4, status: "SUCCESS", taskName: "consume_file"),
                    // Dismissed, so it is gone from the list as well as from the badge. Without this
                    // the row a user swiped away would come straight back on the next refresh.
                    .testValue(acknowledged: true, id: 5, status: "FAILURE", taskName: "consume_file")
                ]
            }
        } operation: {
            let page = try await GetFileTasksUseCase.liveValue.execute(
                server: server,
                status: .failed,
                page: 1
            )

            #expect(page.tasks.map(\.id) == [2, 1])
            #expect(page.nextPage == nil)
        }

        #expect(!v10Requested.value)
    }

    // Nothing negotiated yet reads as the oldest supported server: the newer shape has to be earned
    // by a version this app has actually seen.
    @Test
    func execute_withNoNegotiatedVersion_usesTheOlderShape() async throws {
        let server = Server.testValue()
        let v9Requested = LockIsolated(false)

        try await withDependencies {
            $0.fileTaskRepository.getFileTasksV9 = { _ in
                v9Requested.setValue(true)
                return []
            }
        } operation: {
            _ = try await GetFileTasksUseCase.liveValue.execute(
                server: server,
                status: .complete,
                page: 1
            )
        }

        #expect(v9Requested.value)
    }
}
