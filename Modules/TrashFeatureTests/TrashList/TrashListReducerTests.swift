@testable import TrashFeature

import ApiInterface
import ComposableArchitecture
import Foundation
import SwiftSharing
import Testing
import TestSupport

@MainActor
@Suite(.dependencies())
struct TrashListReducerTests {

    @Test
    func test_onAppear_loadsTheTrash() async {
        let document = Document.testValue(id: 1, title: "Deleted")
        let store = TestStore(initialState: TrashListReducer.State(server: .testValue())) {
            TrashListReducer()
        } withDependencies: {
            $0.getTrash.execute = { _ in .testValue(count: 1, results: [document]) }
        }

        await store.send(.view(.onAppear))
        await store.receive(\.documentsLoaded) {
            $0.documents = [document]
            $0.isLoaded = true
        }
    }

    // Declining must leave the document where it is. The confirmation is the only thing between a
    // swipe and a document nobody can get back.
    @Test
    func test_deleteForever_doesNothingWhenDeclined() async {
        let document = Document.testValue(id: 1, title: "Deleted")
        let emptied = LockIsolated(false)
        let store = TestStore(
            initialState: TrashListReducer.State(server: .testValue())
        ) {
            TrashListReducer()
        } withDependencies: {
            $0.emptyTrash.execute = { _, _ in emptied.setValue(true) }
            $0.trashConfirmation.confirmDeleteForever = { _ in false }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)
        await store.send(.documentsLoaded(.success([document]))) {
            $0.documents = [document]
            $0.isLoaded = true
        }

        await store.send(.view(.deleteForeverButtonTapped(1)))

        #expect(!emptied.value)
        #expect(store.state.documents.count == 1)
    }

    @Test
    func test_deleteForever_removesTheRowWhenConfirmed() async {
        let document = Document.testValue(id: 1, title: "Deleted")
        let store = TestStore(initialState: TrashListReducer.State(server: .testValue())) {
            TrashListReducer()
        } withDependencies: {
            $0.emptyTrash.execute = { _, _ in }
            $0.trashConfirmation.confirmDeleteForever = { _ in true }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)
        await store.send(.documentsLoaded(.success([document]))) {
            $0.documents = [document]
        }

        await store.send(.view(.deleteForeverButtonTapped(1)))
        await store.receive(\.working)
        await store.receive(\.operationFinished) {
            $0.documents = []
            $0.isWorkingOn = []
        }
    }

    @Test
    func test_restore_removesTheRow() async {
        let document = Document.testValue(id: 1, title: "Deleted")
        let restored = LockIsolated<[Document.Id]>([])
        let store = TestStore(initialState: TrashListReducer.State(server: .testValue())) {
            TrashListReducer()
        } withDependencies: {
            $0.restoreDocuments.execute = { ids, _ in restored.setValue(ids) }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)
        await store.send(.documentsLoaded(.success([document]))) {
            $0.documents = [document]
        }

        await store.send(.view(.restoreButtonTapped(1)))
        await store.receive(\.working)
        await store.receive(\.operationFinished) {
            $0.documents = []
        }

        // Restoring is not destructive, so it is not behind a confirmation.
        #expect(restored.value == [1])
    }

    // A failure has to put the row back, or the document looks gone while still being in the trash.
    @Test
    func test_failure_reloadsAndReportsTheError() async {
        let document = Document.testValue(id: 1, title: "Deleted")
        let store = TestStore(initialState: TrashListReducer.State(server: .testValue())) {
            TrashListReducer()
        } withDependencies: {
            $0.getTrash.execute = { _ in .testValue(count: 1, results: [document]) }
            $0.restoreDocuments.execute = { _, _ in throw TestError.someError }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)
        await store.send(.documentsLoaded(.success([document]))) {
            $0.documents = [document]
        }

        await store.send(.view(.restoreButtonTapped(1)))
        await store.receive(\.working)
        await store.receive(\.operationFinished) {
            $0.error = TestError.someError.localizedDescription
        }
        await store.receive(\.documentsLoaded) {
            $0.documents = [document]
        }
    }

    // Seeded explicitly, never left nil: a nil cache fails open and renders every control, which
    // would make a "gated" assertion pass whether or not the gate works.
    @Test
    func trashActionsAreHiddenWithoutDeleteDocument() {
        let server = Server.testValue()

        @Shared(.permissions(server)) var permissions: [Permission]?
        @Shared(.currentUser(server)) var currentUser: User?
        $currentUser.withLock { $0 = .testValue(isSuperuser: false) }
        $permissions.withLock { $0 = [.viewDocument] }

        let state = TrashListReducer.State(server: server)

        #expect(!state.canModifyTrash)
        // The neighbour check: gating trash on a document permission it does not need would
        // compile and look identical.
        #expect(!state.permissions.can(.changeDocument))
    }

    @Test
    func trashActionsAreShownWithDeleteDocument() {
        let server = Server.testValue()

        @Shared(.permissions(server)) var permissions: [Permission]?
        @Shared(.currentUser(server)) var currentUser: User?
        $currentUser.withLock { $0 = .testValue(isSuperuser: false) }
        $permissions.withLock { $0 = [.viewDocument, .deleteDocument] }

        #expect(TrashListReducer.State(server: server).canModifyTrash)
    }

    @Test
    func trashActionsAreShownWhenNothingHasBeenRead() {
        // Fail open. The end-to-end evidence for this is the existing unseeded snapshot, which
        // renders every control; this only re-checks the rule.
        #expect(TrashListReducer.State(server: .testValue()).canModifyTrash)
    }
}
