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
