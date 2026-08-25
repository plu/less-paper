@testable import DocumentsFeature

import ApiInterface
import ComposableArchitecture
import CustomDump
import Foundation
import Testing
import TestSupport

@MainActor
@Suite(
    .dependencies()
)
struct DocumentCustomFieldsReducerTests {

    @Test
    func onAppearResolvesLinkedDocuments() async throws {
        let linked = Document.testValue(id: 2, title: "Contract")
        let state = DocumentCustomFieldsReducer.State.testValue(
            document: .testValue(
                customFields: [.init(field: 6, value: .array([.number(2)]))],
                id: 1
            )
        )
        state.$customFields.withLock {
            $0 = [.testValue(dataType: .documentLink, id: 6, name: "Related")]
        }

        let store = TestStore(initialState: state) {
            DocumentCustomFieldsReducer()
        } withDependencies: {
            $0.getDocumentsByIds.execute = { @Sendable _, _ in [linked] }
        }

        await store.send(.view(.onAppear))
        await store.receive(\.linkedDocuments) {
            $0.linkedDocuments = [linked]
        }
    }

    @Test
    func tappingAResolvedLinkAsksTheViewerToOpenIt() async throws {
        let linked = Document.testValue(id: 2, title: "Contract")
        var state = DocumentCustomFieldsReducer.State.testValue(
            document: .testValue(
                customFields: [.init(field: 6, value: .array([.number(2)]))],
                id: 1
            )
        )
        state.linkedDocuments = [linked]

        let store = TestStore(initialState: state) {
            DocumentCustomFieldsReducer()
        }

        await store.send(.view(.documentLinkTapped(2)))
        await store.receive(\.delegate.openDocument)
    }

    // An unresolved id has no document behind it, so there is nothing to push.
    @Test
    func tappingAnUnresolvedLinkDoesNothing() async throws {
        let store = TestStore(
            initialState: DocumentCustomFieldsReducer.State.testValue(
                document: .testValue(
                    customFields: [.init(field: 6, value: .array([.number(2)]))],
                    id: 1
                )
            )
        ) {
            DocumentCustomFieldsReducer()
        }

        await store.send(.view(.documentLinkTapped(2)))
    }

    @Test
    func aDocumentWithNoFieldsHasNoRows() async throws {
        let state = DocumentCustomFieldsReducer.State.testValue(
            document: .testValue(customFields: [], id: 1)
        )

        #expect(state.rows.isEmpty)
    }

    // The definition can be deleted while the document still references it. The row keeps the id
    // as its name rather than vanishing, so the screen does not under-report the document.
    @Test
    func aFieldWithNoDefinitionKeepsItsIdAsAName() async throws {
        let state = DocumentCustomFieldsReducer.State.testValue(
            document: .testValue(
                customFields: [.init(field: 99, value: .string("orphaned"))],
                id: 1
            )
        )

        expectNoDifference(state.rows.map(\.name), ["#99"])
        #expect(state.rows.first?.value == nil)
    }
}
