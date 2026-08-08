@testable import DocumentsFeature

import ApiInterface
import ComposableArchitecture
import Foundation
import Testing
import TestSupport

@MainActor
@Suite(
    .dependencies()
)
struct DocumentRowReducerTests {

    @Test
    func test_destination_documentForm_delegate_documentUpdated() async throws {
        let document = Document.testValue()
        let store = TestStore(initialState: DocumentRowReducer.State.testValue(
            document: document
        )) {
            DocumentRowReducer()
        }

        await store.send(.view(.editButtonTapped)) {
            $0.destination = .documentForm(.testValue())
        }
        await store.send(.destination(.presented(.documentForm(.delegate(.documentUpdated(.testValue(title: "NEW TITLE"))))))) {
            $0.destination = nil
            $0.document = .testValue(title: "NEW TITLE")
        }
    }

    @Test
    func test_view_rowTapped() async throws {
        let document = Document.testValue()
        let store = TestStore(initialState: DocumentRowReducer.State.testValue(
            document: document
        )) {
            DocumentRowReducer()
        }

        await store.send(.view(.rowTapped))
        await store.receive(\.delegate, .presentDocumentDetail(document))
    }

    @Test
    func test_view_editButtonTapped() async throws {
        let document = Document.testValue()
        let store = TestStore(initialState: DocumentRowReducer.State.testValue(
            document: document
        )) {
            DocumentRowReducer()
        }

        await store.send(.view(.editButtonTapped)) {
            $0.destination = .documentForm(.testValue())
        }
    }
}
