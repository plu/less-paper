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

    @Test
    func test_segmentChanged_reloadsForTheNewSegment() async {
        let asked = LockIsolated<[FileTaskStatus]>([])
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
            $0.getFileTasks.execute = { _, status, _ in
                asked.withValue { $0.append(status) }
                return .testValue(nextPage: nil, tasks: [.testValue(id: 2, status: .complete)])
            }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.binding(.set(\.segment, .complete))) {
            $0.segment = .complete
            // Cleared rather than left in place: rows from the previous segment under a heading that
            // no longer matches them is the one state worse than an empty list.
            $0.tasks = []
            $0.isLoaded = false
        }
        await store.receive(\.tasksLoaded)

        #expect(asked.value == [.complete])
        #expect(store.state.tasks.map(\.id) == [2])
    }

    @Test
    func test_onRowAppear_loadsTheNextPageOnTheLastRow() async {
        let first = FileTask.testValue(id: 1)
        let second = FileTask.testValue(id: 2)
        let store = TestStore(
            initialState: FileTaskListReducer.State(
                tasks: [first],
                isLoaded: true,
                server: .testValue()
            )
        ) {
            FileTaskListReducer()
        } withDependencies: {
            $0.getFileTasks.execute = { _, _, _ in .testValue(nextPage: nil, tasks: [second]) }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)
        // Seeded through the action, not by assigning store.state: a TestStore's state is read-only.
        await store.send(.tasksLoaded(.success(FileTaskPage(nextPage: 2, tasks: [first]))))

        await store.send(.view(.onRowAppear(first)))
        await store.receive(\.moreTasksLoaded)

        #expect(store.state.tasks.map(\.id) == [1, 2])
        #expect(store.state.nextPage == nil)
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
    func test_dismiss_removesTheRow() async {
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
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.view(.dismissButtonTapped(1)))
        await store.receive(\.dismissFinished)

        #expect(store.state.tasks.isEmpty)
        #expect(store.state.isDismissing.isEmpty)
        // Untouched, and deliberately so: AcknowledgeFileTaskUseCase re-reads the count from the
        // server and writes the key. A reducer that decremented it here would drift from the server
        // and fire a second count request per dismiss.
        #expect(failedFileTaskCount == 1)
    }

    @Test
    func test_dismiss_keepsTheRowWhenItFails() async {
        let toasts = LockIsolated<[Toast]>([])
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
            $0.acknowledgeFileTask.execute = { _, _ in throw ApiError.testValue() }
            $0.toastPresenter.present = { value in
                toasts.withValue { $0.append(value) }
            }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.view(.dismissButtonTapped(1)))
        await store.receive(\.dismissFinished)

        #expect(store.state.tasks.map(\.id) == [1])
        #expect(store.state.isDismissing.isEmpty)
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
        let toasts = LockIsolated<[Toast]>([])
        let store = TestStore(
            initialState: FileTaskListReducer.State(
                tasks: [first],
                isLoaded: true,
                server: .testValue()
            )
        ) {
            FileTaskListReducer()
        } withDependencies: {
            $0.getFileTasks.execute = { _, _, _ in throw ApiError.testValue() }
            $0.toastPresenter.present = { value in
                toasts.withValue { $0.append(value) }
            }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)
        await store.send(.tasksLoaded(.success(FileTaskPage(nextPage: 2, tasks: [first]))))

        await store.send(.view(.onRowAppear(first)))
        await store.receive(\.moreTasksLoaded)

        #expect(!store.state.isLoadingMore)
        #expect(store.state.tasks.map(\.id) == [1])
        #expect(toasts.value == [.error("Something went wrong")])
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
