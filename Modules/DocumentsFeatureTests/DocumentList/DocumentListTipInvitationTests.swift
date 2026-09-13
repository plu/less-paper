@testable import DocumentsFeature

import ApiInterface
import ComposableArchitecture
import Testing
import TestSupport

@MainActor
@Suite(
    .dependencies()
)
struct DocumentListTipInvitationTests {

    @Test
    func onAppear_whenEligible_showsTheInvitation() async {
        let store = TestStore(
            initialState: DocumentListReducer.State.testValue(isLoaded: true)
        ) {
            DocumentListReducer()
        } withDependencies: {
            $0.tipInvitation.isEligible = { true }
        }

        await store.send(.view(.onAppear))
        await store.receive(\.tipInvitationEligible) {
            $0.isTipInvitationVisible = true
        }
    }

    @Test
    func onAppear_whenNotEligible_showsNothing() async {
        let store = TestStore(
            initialState: DocumentListReducer.State.testValue(isLoaded: true)
        ) {
            DocumentListReducer()
        } withDependencies: {
            $0.tipInvitation.isEligible = { false }
        }

        await store.send(.view(.onAppear))
        await store.receive(\.tipInvitationEligible)

        #expect(store.state.isTipInvitationVisible == false)
    }

    // Tapping it is an answer, so it settles. Both delegates fire: .tipInvitationSettled is what
    // clears the sibling list (inbox vs documents), and .tipInvitationTapped is what MainReducer
    // turns into a tab switch - this reducer deliberately does not know where the tip jar lives.
    @Test
    func tipInvitationTapped_settlesAndDelegates() async {
        let settled = LockIsolated(0)
        let state = DocumentListReducer.State.testValue(isLoaded: true)
        let store = TestStore(initialState: state) {
            DocumentListReducer()
        } withDependencies: {
            $0.tipInvitation.settle = { settled.withValue { $0 += 1 } }
        }
        await store.send(.set(\.isTipInvitationVisible, true)) {
            $0.isTipInvitationVisible = true
        }

        await store.send(.view(.tipInvitationTapped)) {
            $0.isTipInvitationVisible = false
        }
        await store.receive(\.delegate, .tipInvitationSettled)
        await store.receive(\.delegate, .tipInvitationTapped)

        #expect(settled.value == 1)
    }

    // Dismissing settles identically to tipping, and must delegate identically too - the sibling
    // list has no other way to learn the invitation was answered here.
    @Test
    func tipInvitationDismissed_settlesAndDelegatesSettled() async {
        let settled = LockIsolated(0)
        let store = TestStore(
            initialState: DocumentListReducer.State.testValue(isLoaded: true)
        ) {
            DocumentListReducer()
        } withDependencies: {
            $0.tipInvitation.settle = { settled.withValue { $0 += 1 } }
        }
        await store.send(.set(\.isTipInvitationVisible, true)) {
            $0.isTipInvitationVisible = true
        }

        await store.send(.view(.tipInvitationDismissed)) {
            $0.isTipInvitationVisible = false
        }
        await store.receive(\.delegate, .tipInvitationSettled)

        #expect(settled.value == 1)
    }

    // The eligibility check must survive onAppear's early return for an already-populated list,
    // which is the ordinary way this screen is revisited.
    @Test
    func onAppear_withDocumentsAlreadyLoaded_stillChecks() async {
        let asked = LockIsolated(0)
        let store = TestStore(
            initialState: DocumentListReducer.State.testValue(isLoaded: true)
        ) {
            DocumentListReducer()
        } withDependencies: {
            $0.tipInvitation.isEligible = { asked.withValue { $0 += 1 }; return true }
        }

        await store.send(.view(.onAppear))
        await store.receive(\.tipInvitationEligible) {
            $0.isTipInvitationVisible = true
        }

        #expect(asked.value == 1)
    }
}
