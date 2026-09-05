@testable import DocumentTypesFeature

import ApiInterface
import ComposableArchitecture
import Foundation
import SwiftSharing
import Testing

@MainActor
@Suite
struct DocumentTypeRowReducerTests {

    @Test
    func test_view_deleteButtonTapped_cancelled() async throws {
        let store = TestStore(initialState: DocumentTypeRowReducer.State.testValue()) {
            DocumentTypeRowReducer()
        } withDependencies: {
            $0.deleteConfirmation.present = { _, _ in false }
        }

        await store.send(.view(.deleteButtonTapped))
    }

    @Test
    func test_view_deleteButtonTapped_confirmed() async throws {
        let documentType = DocumentType.testValue()
        let presented = LockIsolated<(title: LocalizedStringResource, name: String)?>(nil)
        let store = TestStore(initialState: DocumentTypeRowReducer.State.testValue(
            documentType: documentType
        )) {
            DocumentTypeRowReducer()
        } withDependencies: {
            $0.deleteConfirmation.present = { title, name in
                presented.setValue((title, name))
                return true
            }
        }

        await store.send(.view(.deleteButtonTapped))
        await store.receive(\.delegate, .deleteDocumentType)

        #expect(presented.value?.title == .deleteDocumentType)
        #expect(presented.value?.name == documentType.name)
    }

    @Test
    func test_view_editButtonTapped() async throws {
        let store = TestStore(initialState: DocumentTypeRowReducer.State.testValue()) {
            DocumentTypeRowReducer()
        }

        await store.send(.view(.editButtonTapped))
        await store.receive(\.delegate, .editDocumentType)
    }

    // A snapshot proves a control is absent; it cannot prove the absence was caused by the right
    // permission. Gating document types on changeTag would compile and look identical.
    @Test
    func rowGatesOnDocumentTypePermissionsSpecifically() {
        let server = Server.testValue()

        @Shared(.currentUser(server))
        var user: User?

        @Shared(.permissions(server))
        var permissions: [Permission]?

        $user.withLock { $0 = .testValue(isSuperuser: false) }
        $permissions.withLock { $0 = [.changeDocumentType] }

        let state = DocumentTypeRowReducer.State(server: server, documentType: .testValue())

        #expect(state.canEdit)
        #expect(!state.canDelete)
        #expect(!state.permissions.can(.changeTag))
    }
}
