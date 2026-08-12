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
}
