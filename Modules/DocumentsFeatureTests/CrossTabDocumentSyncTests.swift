@testable import DocumentsFeature

import ApiInterface
import ComposableArchitecture
import Foundation
import SwiftSharing
import Testing
import TestSupport

/// The two tabs are two `DocumentListReducer.State`s over one server — all `MainReducer` does is
/// hold them — so that is what these tests build. They cover the point of the whole feature: an
/// edit made from one tab reaches the other's rows and detail screens, and changes nothing else.
@MainActor
@Suite(
    .dependencies()
)
struct CrossTabDocumentSyncTests {

    @Test
    func test_editFromOneList_updatesOtherListRow_withoutChangingMembership() async throws {
        let server = Server.testValue()
        let inbox = DocumentListReducer.State.testValue(
            documents: [],
            filter: .inbox(server: server),
            server: server
        )
        let documentList = DocumentListReducer.State.testValue(
            documents: [],
            server: server
        )

        let inboxRows = inbox.rows(for: [
            .testValue(id: 15, title: "Warranty"),
            .testValue(id: 9, title: "Receipt"),
            .testValue(id: 7, title: "Invoice"),
        ])
        let documentListRows = documentList.rows(for: [
            .testValue(id: 7, title: "Invoice"),
            .testValue(id: 12, title: "Contract"),
        ])

        let updatedDocument = Document.testValue(id: 7, title: "Renamed")
        let store = TestStore(initialState: DocumentFormReducer.State(
            document: documentListRows[id: 7]!.$document,
            server: server
        )) {
            DocumentFormReducer()
        }

        await store.send(.updateResult(.success(updatedDocument))) {
            $0.$document.withLock { $0 = updatedDocument }
        }
        await store.receive(\.delegate.documentUpdated)

        // Content propagated to the other tab's row.
        #expect(inboxRows[id: 7]?.document.title == "Renamed")

        // Membership and order did not move in either tab.
        #expect(Array(inboxRows.ids) == [15, 9, 7])
        #expect(Array(documentListRows.ids) == [7, 12])

        // Documents the edit did not touch are unaffected.
        #expect(inboxRows[id: 15]?.document.title == "Warranty")
        #expect(inboxRows[id: 9]?.document.title == "Receipt")
    }

    @Test
    func test_editFromOneList_updatesDetailScreenInOtherList() async throws {
        let server = Server.testValue()
        let inbox = DocumentListReducer.State.testValue(
            documents: [],
            filter: .inbox(server: server),
            server: server
        )
        let documentList = DocumentListReducer.State.testValue(
            documents: [],
            server: server
        )

        let inboxRows = inbox.rows(for: [.testValue(id: 7, title: "Invoice")])
        let documentListRows = documentList.rows(for: [.testValue(id: 7, title: "Invoice")])

        let inboxDetail = DocumentDetailReducer.State(
            document: inboxRows[id: 7]!.$document,
            server: server
        )

        documentListRows[id: 7]!.$document.withLock {
            $0 = .testValue(id: 7, title: "Renamed")
        }

        #expect(inboxDetail.document.title == "Renamed")
    }

    /// Deletion is the deliberate exception to the rule the tests above establish: an edit never
    /// moves a list's membership, but a delete removes the row from *both* tabs.
    @Test
    func test_deleteFromOneList_removesRowFromBothLists() async throws {
        let server = Server.testValue()
        var inboxState = DocumentListReducer.State.testValue(
            documents: [],
            filter: .inbox(server: server),
            server: server
        )
        var documentListState = DocumentListReducer.State.testValue(
            documents: [],
            server: server
        )

        inboxState.documents = inboxState.rows(for: [
            .testValue(id: 15, title: "Warranty"),
            .testValue(id: 7, title: "Invoice"),
        ])
        documentListState.documents = documentListState.rows(for: [
            .testValue(id: 7, title: "Invoice"),
            .testValue(id: 12, title: "Contract"),
        ])

        let documentListStore = TestStore(initialState: documentListState) {
            DocumentListReducer()
        } withDependencies: {
            $0.deleteDocuments.execute = { _, _ in }
        }
        let inboxStore = TestStore(initialState: inboxState) {
            DocumentListReducer()
        }

        await documentListStore.send(.documents(.element(id: 7, action: .delegate(.deleteDocument))))
        await documentListStore.receive(\.isUpdating) {
            $0.documents[id: 7]?.isUpdating = true
        }
        await documentListStore.receive(\.documentsDeleted, [7]) {
            $0.documents.remove(id: 7)
            $0.totalNumberOfDocuments = 41
        }
        await documentListStore.receive(\.delegate, .documentsDeleted([7]))

        // MainReducer forwards the delegate to the other tab; this is that hop.
        await inboxStore.send(.documentsDeleted([7])) {
            $0.documents.remove(id: 7)
            $0.totalNumberOfDocuments = 41
        }

        // The document is gone from both tabs...
        #expect(documentListStore.state.documents.ids.elements == [12])
        #expect(inboxStore.state.documents.ids.elements == [15])

        // ...and the surviving rows kept their order and content.
        #expect(inboxStore.state.documents[id: 15]?.document.title == "Warranty")
        #expect(documentListStore.state.documents[id: 12]?.document.title == "Contract")
    }
}
