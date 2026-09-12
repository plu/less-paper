@testable import DocumentsFeature

import ApiInterface
import ComposableArchitecture
import FileTasksFeature
import Foundation
import SwiftSharing
import Testing
import TestSupport

@MainActor
@Suite(.dependencies())
struct DocumentListFileTasksTests {

    @Test
    func test_fileTasksButtonTapped_presentsTheSheet() async {
        let store = TestStore(initialState: DocumentListReducer.State.testValue()) {
            DocumentListReducer()
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.view(.fileTasksButtonTapped))

        #expect(store.state.destination?.fileTasks != nil)
    }

    // The list screen delegates a document id upward rather than knowing what a document detail is.
    @Test
    func test_fileTaskOpenDocument_pushesTheDetail() async {
        let document = Document.testValue(id: 42)
        let store = TestStore(
            initialState: DocumentListReducer.State.testValue(
                destination: .fileTasks(FileTaskListReducer.State(server: .testValue()))
            )
        ) {
            DocumentListReducer()
        } withDependencies: {
            $0.getDocument.execute = { _, _ in document }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.destination(.presented(.fileTasks(.delegate(.openDocument(42))))))
        await store.receive(\.documentFetched)

        #expect(store.state.path.count == 1)
    }

    // The only thing that ever puts a number on the toolbar button, and the one call the rest of the
    // suite cannot see: runRefreshFailedFileTaskCount sends no action, so an exhaustive TestStore
    // notices neither its presence nor its absence. Also pins where it may fire - InboxView and
    // DocumentListView share this reducer, the badge belongs to the inbox alone, and on a v9 server
    // this read is a full unpaginated GET /api/tasks/ rather than a one-row page.
    @Test
    func test_refresh_readsTheFailedCountForTheInboxOnly() async {
        let asked = LockIsolated<[Server]>([])

        func refresh(filter: DocumentFilter) async {
            let store = TestStore(
                initialState: DocumentListReducer.State.testValue(filter: filter)
            ) {
                DocumentListReducer()
            } withDependencies: {
                $0.getDocuments.execute = { _, _ in .testValue() }
                $0.getFailedFileTaskCount.execute = { server in
                    asked.withValue { $0.append(server) }
                    return 2
                }
                $0.getStatistics.execute = { _ in .testValue() }
            }
            store.exhaustivity = .off(showSkippedAssertions: false)

            await store.send(.view(.onRefresh))
            await store.finish()
        }

        await refresh(filter: .testValue(isInbox: true))
        #expect(asked.value == [.testValue()])

        await refresh(filter: .testValue())
        // Still one: the documents list renders no badge, so it asks for no count.
        #expect(asked.value == [.testValue()])
    }

    @Test
    func test_fileTaskClose_dismissesTheSheet() async {
        let store = TestStore(
            initialState: DocumentListReducer.State.testValue(
                destination: .fileTasks(FileTaskListReducer.State(server: .testValue()))
            )
        ) {
            DocumentListReducer()
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.destination(.presented(.fileTasks(.delegate(.close)))))

        #expect(store.state.destination == nil)
    }
}
