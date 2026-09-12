@testable import FileTasksFeature

import ApiInterface
import Components
import ComposableArchitecture
import Foundation
import SwiftSharing
import Testing
import TestSupport

@MainActor
@Suite(.dependencies())
struct FileTaskListReducerTests {

    @Test
    func test_onAppear_loadsTheSelectedSegment() async {
        let task = FileTask.testValue(id: 1, status: .failed)
        let store = TestStore(initialState: FileTaskListReducer.State(server: .testValue())) {
            FileTaskListReducer()
        } withDependencies: {
            $0.getFileTasks.execute = { _, _, _ in .testValue(nextPage: nil, tasks: [task]) }
        }

        await store.send(.view(.onAppear))
        await store.receive(\.tasksLoaded) {
            $0.tasks = [task]
            $0.isLoaded = true
        }
    }

    // The sheet opens on the problem when there is one, and on the newest imports when there is not.
    @Test
    func test_initialSegment_followsTheFailureCount() async {
        let server = Server.testValue()
        @Shared(.failedFileTaskCount(server))
        var failedFileTaskCount: Int

        #expect(FileTaskListReducer.State(server: server).segment == .complete)

        $failedFileTaskCount.withLock { $0 = 2 }

        #expect(FileTaskListReducer.State(server: server).segment == .failed)
    }

    // The load in flight is cancelled rather than left to land: the clock is advanced at the end, so
    // the old segment's rows would arrive as an unreceived action if it were not.
    @Test
    func test_segmentChanged_cancelsTheLoadInFlight() async {
        let asked = LockIsolated<[FileTaskStatus]>([])
        let clock = TestClock()
        let stale = FileTask.testValue(id: 1, status: .failed)
        let fresh = FileTask.testValue(id: 2)
        let store = TestStore(
            initialState: FileTaskListReducer.State(segment: .failed, server: .testValue())
        ) {
            FileTaskListReducer()
        } withDependencies: {
            $0.continuousClock = clock
            $0.getFileTasks.execute = { _, status, _ in
                asked.withValue { $0.append(status) }
                guard status == .complete else {
                    try await clock.sleep(for: .seconds(1))
                    return .testValue(nextPage: nil, tasks: [stale])
                }
                return .testValue(nextPage: nil, tasks: [fresh])
            }
        }

        await store.send(.view(.onAppear))
        await store.send(.binding(.set(\.segment, .complete))) {
            // Everything else the branch clears is already clear on a list that never loaded.
            $0.segment = .complete
        }
        await store.receive(\.tasksLoaded) {
            $0.isLoaded = true
            $0.tasks = [fresh]
        }
        await clock.advance(by: .seconds(1))

        #expect(asked.value == [.failed, .complete])
        #expect(store.state.tasks.map(\.id) == [2])
    }

    // Rows from the previous segment under a heading that no longer matches them is the one state
    // worse than an empty list, and the next page in flight is how they would get there.
    @Test
    func test_segmentChanged_dropsTheNextPageInFlight() async {
        let clock = TestClock()
        let first = FileTask.testValue(id: 1, status: .failed)
        let stale = FileTask.testValue(id: 2, status: .failed)
        let fresh = FileTask.testValue(id: 3)
        let store = TestStore(
            initialState: FileTaskListReducer.State(segment: .failed, server: .testValue())
        ) {
            FileTaskListReducer()
        } withDependencies: {
            $0.continuousClock = clock
            $0.getFileTasks.execute = { _, status, _ in
                guard status == .complete else {
                    try await clock.sleep(for: .seconds(1))
                    return .testValue(nextPage: 3, tasks: [stale])
                }
                return .testValue(nextPage: nil, tasks: [fresh])
            }
        }

        // Seeded through the action, not by assigning store.state: a TestStore's state is read-only.
        await store.send(.tasksLoaded(.success(.testValue(nextPage: 2, tasks: [first])))) {
            $0.isLoaded = true
            $0.nextPage = 2
            $0.tasks = [first]
        }
        await store.send(.view(.onRowAppear(first))) {
            $0.isLoadingMore = true
        }
        await store.send(.binding(.set(\.segment, .complete))) {
            $0.isLoaded = false
            // The cancelled page cannot clear this itself, and the new segment cannot page until it
            // is clear.
            $0.isLoadingMore = false
            $0.nextPage = nil
            $0.segment = .complete
            $0.tasks = []
        }
        await store.receive(\.tasksLoaded) {
            $0.isLoaded = true
            $0.tasks = [fresh]
        }
        await clock.advance(by: .seconds(1))

        #expect(store.state.tasks.map(\.id) == [3])
        #expect(store.state.nextPage == nil)
    }

    @Test
    func test_onRowAppear_loadsTheNextPageOnTheLastRow() async {
        let first = FileTask.testValue(id: 1)
        let second = FileTask.testValue(id: 2)
        let store = TestStore(
            initialState: FileTaskListReducer.State(server: .testValue())
        ) {
            FileTaskListReducer()
        } withDependencies: {
            $0.getFileTasks.execute = { _, _, _ in .testValue(nextPage: nil, tasks: [second]) }
        }

        await store.send(.tasksLoaded(.success(.testValue(nextPage: 2, tasks: [first])))) {
            $0.isLoaded = true
            $0.nextPage = 2
            $0.tasks = [first]
        }
        await store.send(.view(.onRowAppear(first))) {
            $0.isLoadingMore = true
        }
        await store.receive(\.moreTasksLoaded) {
            $0.isLoadingMore = false
            $0.nextPage = nil
            $0.tasks = [first, second]
        }
    }

    @Test
    func test_onRowAppear_doesNothingWithNoNextPage() async {
        let first = FileTask.testValue(id: 1)
        let asked = LockIsolated(false)
        let store = TestStore(
            initialState: FileTaskListReducer.State(
                tasks: [first],
                isLoaded: true,
                server: .testValue()
            )
        ) {
            FileTaskListReducer()
        } withDependencies: {
            $0.getFileTasks.execute = { _, _, _ in
                asked.setValue(true)
                return .testValue()
            }
        }

        await store.send(.view(.onRowAppear(first)))

        #expect(!asked.value)
    }

    @Test
    func test_dismiss_marksTheRowThenRemovesIt() async {
        let server = Server.testValue()
        @Shared(.failedFileTaskCount(server))
        var failedFileTaskCount: Int
        $failedFileTaskCount.withLock { $0 = 1 }

        let store = TestStore(
            initialState: FileTaskListReducer.State(
                segment: .failed,
                tasks: [.testValue(id: 1, status: .failed)],
                isLoaded: true,
                server: server
            )
        ) {
            FileTaskListReducer()
        } withDependencies: {
            $0.acknowledgeFileTask.execute = { _, _ in }
        }

        await store.send(.view(.dismissButtonTapped(1))) {
            $0.isDismissing = [1]
        }
        await store.receive(\.dismissFinished) {
            $0.isDismissing = []
            $0.tasks = []
        }

        // Untouched, and deliberately so: AcknowledgeFileTaskUseCase re-reads the count from the
        // server and writes the key. A reducer that decremented it here would drift from the server
        // and fire a second count request per dismiss.
        #expect(failedFileTaskCount == 1)
    }

    @Test
    func test_dismiss_ignoresASecondTapOnTheSameRow() async {
        let acknowledged = LockIsolated(0)
        let clock = TestClock()
        let store = TestStore(
            initialState: FileTaskListReducer.State(
                segment: .failed,
                tasks: [.testValue(id: 1, status: .failed)],
                isLoaded: true,
                server: .testValue()
            )
        ) {
            FileTaskListReducer()
        } withDependencies: {
            $0.acknowledgeFileTask.execute = { _, _ in
                acknowledged.withValue { $0 += 1 }
                try await clock.sleep(for: .seconds(1))
            }
        }

        await store.send(.view(.dismissButtonTapped(1))) {
            $0.isDismissing = [1]
        }
        // A row already marked asks nothing. A slow server must not be told twice.
        await store.send(.view(.dismissButtonTapped(1)))
        await clock.advance(by: .seconds(1))
        await store.receive(\.dismissFinished) {
            $0.isDismissing = []
            $0.tasks = []
        }

        #expect(acknowledged.value == 1)
    }

    @Test
    func test_dismiss_keepsTheRowWhenItFails() async {
        let task = FileTask.testValue(id: 1, status: .failed)
        let toasts = LockIsolated<[Toast]>([])
        let store = TestStore(
            initialState: FileTaskListReducer.State(
                segment: .failed,
                tasks: [task],
                isLoaded: true,
                server: .testValue()
            )
        ) {
            FileTaskListReducer()
        } withDependencies: {
            $0.acknowledgeFileTask.execute = { _, _ in throw ApiError.testValue() }
            $0.toastPresenter.present = { value in
                toasts.withValue { $0.append(value) }
            }
        }

        await store.send(.view(.dismissButtonTapped(1))) {
            $0.isDismissing = [1]
        }
        await store.receive(\.dismissFinished) {
            // Unmarked but not removed, so the row can be tried again.
            $0.isDismissing = []
        }

        #expect(store.state.tasks == [task])
        #expect(toasts.value == [.error("Something went wrong")])
    }

    // isLoaded is set even on a failure, so the list settles into its empty state with pull to
    // refresh working rather than spinning forever.
    @Test
    func test_loadFailure_toastsAndSettlesTheList() async {
        let toasts = LockIsolated<[Toast]>([])
        let store = TestStore(initialState: FileTaskListReducer.State(server: .testValue())) {
            FileTaskListReducer()
        } withDependencies: {
            $0.getFileTasks.execute = { _, _, _ in throw ApiError.testValue() }
            $0.toastPresenter.present = { value in
                toasts.withValue { $0.append(value) }
            }
        }

        await store.send(.view(.onAppear))
        await store.receive(\.tasksLoaded) {
            $0.isLoaded = true
        }

        #expect(toasts.value == [.error("Something went wrong")])
    }

    // A failed next page has to release isLoadingMore, or the row that asked for it can never ask
    // again and the list is stuck at the page it has.
    @Test
    func test_nextPageFailure_letsTheListAskAgain() async {
        let first = FileTask.testValue(id: 1)
        let asked = LockIsolated(0)
        let toasts = LockIsolated<[Toast]>([])
        let store = TestStore(
            initialState: FileTaskListReducer.State(server: .testValue())
        ) {
            FileTaskListReducer()
        } withDependencies: {
            $0.getFileTasks.execute = { _, _, _ in
                asked.withValue { $0 += 1 }
                throw ApiError.testValue()
            }
            $0.toastPresenter.present = { value in
                toasts.withValue { $0.append(value) }
            }
        }

        await store.send(.tasksLoaded(.success(.testValue(nextPage: 2, tasks: [first])))) {
            $0.isLoaded = true
            $0.nextPage = 2
            $0.tasks = [first]
        }
        await store.send(.view(.onRowAppear(first))) {
            $0.isLoadingMore = true
        }
        await store.receive(\.moreTasksLoaded) {
            $0.isLoadingMore = false
        }

        // The point of the test: the same row asks a second time and is served, which a standing
        // isLoadingMore would have made impossible.
        await store.send(.view(.onRowAppear(first))) {
            $0.isLoadingMore = true
        }
        await store.receive(\.moreTasksLoaded) {
            $0.isLoadingMore = false
        }

        #expect(asked.value == 2)
        #expect(store.state.tasks.map(\.id) == [1])
        #expect(store.state.nextPage == 2)
        #expect(toasts.value == [.error("Something went wrong"), .error("Something went wrong")])
    }

    // The swipe action is gated on changePaperlessTask, and ServerPermissions answers true for
    // everything until a permission set has been fetched - so only a seeded, restricted one reaches
    // the false branch at all. Without this, `if canDismiss` could be deleted and nothing would fail.
    @Test
    func test_canDismiss_followsTheChangePaperlessTaskPermission() async {
        let server = Server.testValue()
        @Shared(.currentUser(server))
        var currentUser: User?
        @Shared(.permissions(server))
        var permissions: [Permission]?
        $currentUser.withLock { $0 = .testValue(isSuperuser: false) }

        $permissions.withLock { $0 = [.viewPaperlessTask, .changePaperlessTask] }
        #expect(FileTaskListReducer.State(server: server).canDismiss)

        $permissions.withLock { $0 = [.viewPaperlessTask] }
        #expect(!FileTaskListReducer.State(server: server).canDismiss)
    }

    @Test
    func test_rowTapped_delegatesADocumentItCanOpen() async {
        let task = FileTask.testValue(documentId: 42, id: 1)
        let store = TestStore(
            initialState: FileTaskListReducer.State(tasks: [task], isLoaded: true, server: .testValue())
        ) {
            FileTaskListReducer()
        }

        await store.send(.view(.rowTapped(task)))
        await store.receive(\.delegate.openDocument)
    }

    @Test
    func test_rowTapped_doesNothingWithoutADocument() async {
        let task = FileTask.testValue(documentId: nil, id: 1, status: .queued)
        let store = TestStore(
            initialState: FileTaskListReducer.State(tasks: [task], isLoaded: true, server: .testValue())
        ) {
            FileTaskListReducer()
        }

        await store.send(.view(.rowTapped(task)))
    }
}
