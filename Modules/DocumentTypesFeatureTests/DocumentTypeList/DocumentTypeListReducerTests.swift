@testable import DocumentTypesFeature

import ApiInterface
import Components
import ComposableArchitecture
import Foundation
import SwiftSharing
import Testing

@MainActor
@Suite
struct DocumentTypeListReducerTests {

    @Test
    func test_destination_presented_documentTypeForm_delegate_documentTypeSaved_insert() async throws {
        let store = TestStore(initialState: DocumentTypeListReducer.State(
            documentTypes: [.testValue()],
            destination: .documentTypeForm(DocumentTypeFormReducer.State(server: .testValue())),
            server: .testValue()
        )) {
            DocumentTypeListReducer()
        }

        await store.send(.destination(.presented(.documentTypeForm(.delegate(.documentTypeSaved(.testValue(
            id: 2,
            name: "New name"
        ))))))) {
            $0.destination = nil
            $0.documentTypes = [
                .testValue(documentType: .testValue(id: 2, name: "New name")),
                .testValue()
            ]
        }
    }

    @Test
    func test_destination_presented_documentTypeForm_delegate_documentTypeSaved_update() async throws {
        @Shared(.documentTypes(.testValue()))
        var cachedDocumentTypes = .init()

        let store = TestStore(initialState: DocumentTypeListReducer.State(
            documentTypes: [.testValue()],
            destination: .documentTypeForm(DocumentTypeFormReducer.State(documentType: .testValue(), server: .testValue())),
            server: .testValue()
        )) {
            DocumentTypeListReducer()
        }

        await store.send(.destination(.presented(.documentTypeForm(.delegate(.documentTypeSaved(.testValue(name: "New name"))))))) {
            $0.destination = nil
            $0.documentTypes = [.testValue(documentType: .testValue(name: "New name"))]
        }
    }

    @Test
    func test_documentTypes_element_delegate_deleteDocumentType_error() async throws {
        @Shared(.documentTypes(.testValue()))
        var cachedDocumentTypes = .init(uniqueElements: [.testValue()])

        let toasts = LockIsolated<[Toast]>([])
        let store = TestStore(initialState: DocumentTypeListReducer.State(
            documentTypes: [.testValue()],
            server: .testValue()
        )) {
            DocumentTypeListReducer()
        } withDependencies: {
            $0.deleteDocumentType.execute = { _, _ in
                throw ApiError.testValue()
            }
            $0.toastPresenter.present = { value in
                toasts.withValue { $0.append(value) }
            }
        }

        await store.send(.documentTypes(.element(id: 1, action: .delegate(.deleteDocumentType))))
        await store.receive(\.isUpdating) {
            $0.documentTypes[id: 1]?.isUpdating = true
        }
        await store.receive(\.error)
        await store.receive(\.isUpdating) {
            $0.documentTypes[id: 1]?.isUpdating = false
        }
        #expect(toasts.value == [.error("Something went wrong")])
    }

    @Test
    func test_documentTypes_element_delegate_deleteDocumentType_success() async throws {
        @Shared(.documentTypes(.testValue()))
        var cachedDocumentTypes = .init()

        let deleteDocumentTypeReceived = LockIsolated<DocumentType.Id?>(nil)
        let store = TestStore(initialState: DocumentTypeListReducer.State(
            documentTypes: [.testValue()],
            server: .testValue()
        )) {
            DocumentTypeListReducer()
        } withDependencies: {
            $0.deleteDocumentType.execute = { id, _ in
                deleteDocumentTypeReceived.setValue(id)
            }
        }

        await store.send(.documentTypes(.element(id: 1, action: .delegate(.deleteDocumentType))))
        await store.receive(\.isUpdating) {
            $0.documentTypes[id: 1]?.isUpdating = true
        }
        await store.receive(\.documentTypeDeleted) {
            $0.documentTypes = []
        }
    }

    @Test
    func test_documentTypes_element_delegate_editDocumentType() async throws {
        let store = TestStore(initialState: DocumentTypeListReducer.State(
            documentTypes: [.testValue()],
            server: .testValue()
        )) {
            DocumentTypeListReducer()
        }

        await store.send(.documentTypes(.element(id: 1, action: .delegate(.editDocumentType)))) {
            $0.destination = .documentTypeForm(DocumentTypeFormReducer.State(
                documentType: .testValue(),
                server: .testValue()
            ))
        }
    }

    @Test
    func test_view_createButtonTapped() async throws {
        let store = TestStore(initialState: DocumentTypeListReducer.State(
            documentTypes: [.testValue()],
            server: .testValue()
        )) {
            DocumentTypeListReducer()
        }

        await store.send(.view(.createDocumentTypeButtonTapped)) {
            $0.destination = .documentTypeForm(DocumentTypeFormReducer.State(
                server: .testValue()
            ))
        }
    }

    @Test
    func test_view_onAppear_success() async throws {
        @Shared(.documentTypes(.testValue()))
        var cachedDocumentTypes = .init()

        let getDocumentTypesResult = [DocumentType.testValue()]
        let store = TestStore(initialState: DocumentTypeListReducer.State(server: .testValue())) {
            DocumentTypeListReducer()
        } withDependencies: {
            $0.getDocumentTypes.execute = { _ in getDocumentTypesResult }
        }

        await store.send(.view(.onAppear))
        await store.receive(\.getDocumentTypesResult, getDocumentTypesResult) {
            $0.documentTypes = IdentifiedArray(
                uniqueElements: getDocumentTypesResult.map {
                    DocumentTypeRowReducer.State(
                        server: .testValue(),
                        documentType: $0
                    )
                }
            )
        }
        await store.receive(\.binding, .set(\.isLoaded, true)) {
            $0.isLoaded = true
        }
    }

    // The toolbar "+" is gated on .addDocumentType, but this project's NavigationStack snapshots do
    // not render nav-bar chrome, so no image can show its absence. This asserts the gate instead -
    // and the third expectation is the one that catches gating document types on a neighbouring
    // entity's permission, which would compile and look identical.
    @Test
    func listGatesOnDocumentTypePermissionsSpecifically() {
        let server = Server.testValue()

        @Shared(.currentUser(server))
        var user: User?

        @Shared(.permissions(server))
        var permissions: [Permission]?

        $user.withLock { $0 = .testValue(isSuperuser: false) }
        $permissions.withLock { $0 = [.viewDocumentType] }

        let state = DocumentTypeListReducer.State(server: server)

        #expect(!state.canCreate)
        #expect(state.permissions.can(.viewDocumentType))
        #expect(!state.permissions.can(.addTag))
    }

    // This restates ServerPermissionsTests.nilCacheAllowsEverything: with a nil cache, can
    // returns true for any server, so this passes even if State wired ServerPermissions to a
    // different Server entirely. The genuinely end-to-end fail-open evidence is the pre-existing,
    // unseeded testSnapshot.empty.png in DocumentTypeListViewTests - it renders every control
    // with no cache seeded at all. This test only re-checks the rule.
    @Test
    func listAllowsEverythingWhenNothingHasBeenRead() {
        let state = DocumentTypeListReducer.State(server: .testValue())

        #expect(state.canCreate)
    }
}
