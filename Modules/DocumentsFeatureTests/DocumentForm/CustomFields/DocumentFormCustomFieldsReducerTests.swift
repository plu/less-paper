@testable import DocumentsFeature

import ApiInterface
import ComposableArchitecture
import CustomFieldsFeature
import Foundation
import IdentifiedCollections
import SwiftSharing
import Testing
import TestSupport

// Local rather than appended to `[CustomField].previewValue`: that array is the fixture behind four
// recorded snapshot suites, and growing it would invalidate every one of them.
let customFieldFixtures = IdentifiedArray(uniqueElements: [CustomField].previewValue + [
    .testValue(dataType: .documentLink, documentCount: 18, id: 6, name: "Related"),
    .testValue(dataType: .integer, documentCount: 21, id: 7, name: "Pages"),
    .testValue(dataType: .unknown, documentCount: 24, id: 8, name: "Future type"),
])

// The definitions are read through storage keyed by server id. Tests run in parallel and would
// otherwise all write the same file, so each one gets a server of its own.
private func server(_ id: String) -> Server {
    .testValue(id: id)
}

@MainActor
@Suite(
    .dependencies {
        $0.apiCache.customField = { id, _ in
            guard let id else {
                return nil
            }
            return customFieldFixtures[id: id]
        }
    }
)
struct DocumentFormCustomFieldsReducerTests {

    @Test
    func test_view_addCustomFieldTapped() async throws {
        let store = TestStore(initialState: DocumentFormReducer.State.testValue(
            server: server("add")
        )) {
            DocumentFormReducer()
        }

        await store.send(.view(.addCustomFieldTapped(1))) {
            $0.input.customFields = [.init(id: 1, value: .text(""))]
        }
    }

    // A boolean has no empty state a Toggle could show, so it attaches as a definite No.
    @Test
    func test_view_addCustomFieldTapped_booleanStartsFalse() async throws {
        let store = TestStore(initialState: DocumentFormReducer.State.testValue(
            server: server("addBoolean")
        )) {
            DocumentFormReducer()
        }

        await store.send(.view(.addCustomFieldTapped(3))) {
            $0.input.customFields = [.init(id: 3, value: .boolean(false))]
        }
    }

    @Test
    func test_view_addCustomFieldTapped_ignoresAFieldAlreadyAttached() async throws {
        var state = DocumentFormReducer.State.testValue(server: server("addAttached"))
        state.input.customFields = [.init(id: 1, value: .text("Ref"))]
        let store = TestStore(initialState: state) {
            DocumentFormReducer()
        }

        await store.send(.view(.addCustomFieldTapped(1)))
    }

    @Test
    func test_view_createCustomFieldButtonTapped() async throws {
        let state = DocumentFormReducer.State.testValue(server: server("create"))
        let store = TestStore(initialState: state) {
            DocumentFormReducer()
        }

        await store.send(.view(.createCustomFieldButtonTapped)) {
            $0.destination = .customFieldForm(.init(server: state.server))
        }
    }

    // Creating the definition and putting it on the document is one intent: the user reached the
    // form from the add menu.
    @Test
    func test_destination_customFieldForm_delegate_customFieldSaved() async throws {
        let state = DocumentFormReducer.State.testValue(server: server("created"))
        let store = TestStore(initialState: state) {
            DocumentFormReducer()
        }
        store.exhaustivity = .off(showSkippedAssertions: false)
        await store.send(.view(.createCustomFieldButtonTapped))

        await store.send(.destination(.presented(.customFieldForm(.delegate(
            .customFieldSaved(.testValue(dataType: .string, id: 42, name: "Reference"))
        ))))) {
            $0.destination = nil
            $0.input.customFields = [.init(id: 42, value: .text(""))]
        }
    }

    @Test
    func test_view_removeCustomFieldTapped() async throws {
        var state = DocumentFormReducer.State.testValue(server: server("remove"))
        state.input.customFields = [
            .init(id: 1, value: .text("Ref")),
            .init(id: 3, value: .boolean(true)),
        ]
        let store = TestStore(initialState: state) {
            DocumentFormReducer()
        }

        await store.send(.view(.removeCustomFieldTapped(1))) {
            $0.input.customFields = [.init(id: 3, value: .boolean(true))]
        }
    }

    @Test
    func test_view_documentLinkTapped() async throws {
        var state = DocumentFormReducer.State.testValue(server: server("link"))
        state.input.customFields = [.init(id: 6, value: .documentLink([2]))]
        state.linkedCustomFieldDocuments = [.testValue(id: 2, title: "Related")]
        let store = TestStore(initialState: state) {
            DocumentFormReducer()
        }

        await store.send(.view(.documentLinkTapped(6))) {
            $0.documentLinkFieldId = 6
            $0.destination = .documentPicker(.testValue(
                selection: [.testValue(id: 2, title: "Related")],
                server: state.server
            ))
        }
    }

    // The picker reports every tap, so the value tracks the selection live rather than waiting for
    // the sheet to close.
    @Test
    func test_destination_documentPicker_delegate_selectionChanged() async throws {
        var state = DocumentFormReducer.State.testValue(server: server("selection"))
        state.input.customFields = [.init(id: 6, value: .documentLink([]))]
        state.documentLinkFieldId = 6
        state.destination = .documentPicker(.testValue(
            selection: [.testValue(id: 2, title: "Related")],
            server: state.server
        ))
        let store = TestStore(initialState: state) {
            DocumentFormReducer()
        }

        await store.send(.destination(.presented(.documentPicker(.delegate(.selectionChanged([2])))))) {
            $0.input.customFields[id: 6]?.value = .documentLink([2])
            $0.linkedCustomFieldDocuments = [.testValue(id: 2, title: "Related")]
        }
    }

    // The titles are resolved even when the full document is already loaded: the lookup is keyed
    // off the staged values, not off whether onAppear also has a document to fetch.
    @Test
    func test_view_onAppear_resolvesLinkedCustomFieldDocuments() async throws {
        var state = DocumentFormReducer.State.testValue(
            content: "loaded",
            server: server("resolve")
        )
        state.input.customFields = [.init(id: 6, value: .documentLink([2]))]
        let store = TestStore(initialState: state) {
            DocumentFormReducer()
        } withDependencies: {
            $0.getDocumentsByIds.execute = { _, _ in [.testValue(id: 2, title: "Related")] }
        }

        await store.send(.view(.onAppear))
        await store.receive(\.linkedCustomFieldDocuments) {
            $0.linkedCustomFieldDocuments = [.testValue(id: 2, title: "Related")]
        }
    }

    @Test
    func test_view_onAppear_skipsTheLookupWithNoLinkedValues() async throws {
        let store = TestStore(initialState: DocumentFormReducer.State.testValue(
            content: "loaded",
            server: server("resolveNone")
        )) {
            DocumentFormReducer()
        }

        await store.send(.view(.onAppear))
    }

    @Test
    func test_destination_dismiss_clearsTheDocumentLinkField() async throws {
        var state = DocumentFormReducer.State.testValue(server: server("dismiss"))
        state.input.customFields = [.init(id: 6, value: .documentLink([]))]
        state.documentLinkFieldId = 6
        state.destination = .documentPicker(.testValue(server: state.server))
        let store = TestStore(initialState: state) {
            DocumentFormReducer()
        }

        await store.send(.destination(.dismiss)) {
            $0.destination = nil
            $0.documentLinkFieldId = nil
        }
    }
}
