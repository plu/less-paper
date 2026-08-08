@testable import DocumentTypesFeature

import ApiInterface
import ComposableArchitecture
import Foundation
import Testing

@MainActor
@Suite
struct DocumentTypeRowReducerTests {

    @Test
    func test_destination_confirmation_deleteButtonTapped() async throws {
        let store = TestStore(initialState: DocumentTypeRowReducer.State(
            documentType: .testValue(),
            destination: .confirmation(.confirmDelete(name: "Inbox")),
            server: .testValue()
        )) {
            DocumentTypeRowReducer()
        }

        await store.send(.destination(.presented(.confirmation(.deleteButtonTapped)))) {
            $0.destination = nil
        }
        await store.receive(\.delegate, .deleteDocumentType)
    }

    @Test
    func test_view_deleteButtonTapped() async throws {
        let documentType = DocumentType.testValue()
        let store = TestStore(initialState: DocumentTypeRowReducer.State(
            documentType: documentType,
            server: .testValue()
        )) {
            DocumentTypeRowReducer()
        }

        await store.send(.view(.deleteButtonTapped)) {
            $0.destination = .confirmation(.confirmDelete(name: documentType.name))
        }
    }

    @Test
    func test_view_editButtonTapped() async throws {
        let store = TestStore(initialState: DocumentTypeRowReducer.State(
            documentType: .testValue(),
            server: .testValue()
        )) {
            DocumentTypeRowReducer()
        }

        await store.send(.view(.editButtonTapped))
        await store.receive(\.delegate, .editDocumentType)
    }
}
