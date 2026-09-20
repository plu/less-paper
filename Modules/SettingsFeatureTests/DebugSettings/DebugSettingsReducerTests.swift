#if DEBUG
@testable import SettingsFeature

import Components
import ComposableArchitecture
import Dependencies
import Foundation
import Testing
import TestSupport

@MainActor
@Suite(
    .testDependencies()
)
struct DebugSettingsReducerTests {

    // The screen exists to make a gate reachable that needs 60 days of tenure and 15 distinct days
    // of use, so this is the assertion that matters: one tap and the real gate says yes. Note the
    // snapshot's `isEligible` is TipInvitation's own verdict, not a re-derivation, so this also
    // proves the button satisfies every condition rather than merely the ones it writes.
    @Test
    func makeEligibleButtonTapped_makesTheRealGateSayYes() async {
        let store = testStore()

        await store.send(.view(.makeEligibleButtonTapped))
        await store.receive(\.snapshotLoaded)

        #expect(store.state.snapshot?.isEligible == true)
        #expect(store.state.snapshot?.hasEnoughTenure == true)
        #expect(store.state.snapshot?.hasEnoughActiveDays == true)
        #expect(store.state.snapshot?.isSettled == false)
    }

    @Test
    func resetButtonTapped_looksLikeAFreshInstall() async {
        let store = testStore()
        await store.send(.view(.makeEligibleButtonTapped))
        await store.receive(\.snapshotLoaded)

        await store.send(.view(.resetButtonTapped))
        await store.receive(\.snapshotLoaded)

        #expect(store.state.snapshot?.firstActiveAt == nil)
        #expect(store.state.snapshot?.activeDays == 0)
        #expect(store.state.snapshot?.isEligible == false)
    }

    // Answering the invitation is permanent by design, so this button is the only way back.
    @Test
    func clearAnsweredButtonTapped_undoesTheAnswer() async {
        let store = testStore()
        await store.send(.view(.makeEligibleButtonTapped))
        await store.receive(\.snapshotLoaded)

        await withDependencies {
            $0.defaultAppStorage = appStorage
        } operation: {
            await TipInvitation.liveValue.settle()
        }

        await store.send(.view(.onAppear))
        await store.receive(\.snapshotLoaded)
        #expect(store.state.snapshot?.isSettled == true)
        #expect(store.state.snapshot?.isEligible == false)

        await store.send(.view(.clearAnsweredButtonTapped))
        await store.receive(\.snapshotLoaded)

        #expect(store.state.snapshot?.isSettled == false)
        #expect(store.state.snapshot?.isEligible == true)
    }

    @Test
    func onAppear_readsWithoutChangingAnything() async {
        let store = testStore()

        await store.send(.view(.onAppear))
        await store.receive(\.snapshotLoaded)

        #expect(store.state.snapshot?.activeDays == 0)
        #expect(store.state.snapshot?.firstActiveAt == nil)
        #expect(store.state.snapshot?.isEligible == false)
    }

    private func testStore() -> TestStoreOf<DebugSettingsReducer> {
        let store = TestStore(
            initialState: DebugSettingsReducer.State(),
            reducer: { DebugSettingsReducer() },
            withDependencies: {
                $0.date = .constant(Self.now)
                $0.defaultAppStorage = appStorage
            }
        )
        // Off because the snapshot carries a dozen fields and each test is about three of them; the
        // #expects below assert what they name, which a state-mutation closure could not do anyway
        // since Snapshot's fields are `let`.
        store.exhaustivity = .off(showSkippedAssertions: false)
        return store
    }

    private static let now = Date(timeIntervalSince1970: 1_600_000_000)

    // An instance property, not a static one: Swift Testing builds a fresh instance per test, so
    // this gives each test its own store while keeping one store within a test. A computed static
    // would hand out a different store on every access and quietly break the tests that write
    // through one reference and read through another.
    private let appStorage = UserDefaults.inMemory
}
#endif
