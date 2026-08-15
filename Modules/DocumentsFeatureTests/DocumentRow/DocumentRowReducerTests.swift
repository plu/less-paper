@testable import DocumentsFeature

import ApiInterface
import ComposableArchitecture
import Foundation
import SwiftSharing
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
        await store.send(.destination(.presented(.documentForm(.delegate(.documentUpdated))))) {
            $0.destination = nil
        }
    }

    @Test
    func test_view_deleteButtonTapped_confirmed() async throws {
        let documentTitle = LockIsolated<String?>(nil)
        let store = TestStore(initialState: DocumentRowReducer.State.testValue(
            document: .testValue(title: "Invoice")
        )) {
            DocumentRowReducer()
        } withDependencies: {
            $0.documentDeleteConfirmation.present = { title in
                documentTitle.setValue(title)
                return true
            }
        }

        await store.send(.view(.deleteButtonTapped))
        await store.receive(\.delegate, .deleteDocument)

        #expect(documentTitle.value == "Invoice")
    }

    @Test
    func test_view_deleteButtonTapped_cancelled() async throws {
        let store = TestStore(initialState: DocumentRowReducer.State.testValue(
            document: .testValue(title: "Invoice")
        )) {
            DocumentRowReducer()
        } withDependencies: {
            $0.documentDeleteConfirmation.present = { _ in false }
        }

        await store.send(.view(.deleteButtonTapped))
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
        await store.receive(\.delegate, .presentDocumentDetail(Shared(value: document)))
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
