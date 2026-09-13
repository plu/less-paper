@testable import AppFeature
@testable import SettingsFeature

import ApiInterface
import ComposableArchitecture
import Testing
import TestSupport

@MainActor
@Suite(
    .dependencies()
)
struct AppReducerTipInvitationTests {

    // A cold launch never reaches didBecomeActive - onChange(of: scenePhase) does not fire for the
    // phase the app launched into - so bootstrap has to record the day too, or the very session a
    // fresh launch starts would never count.
    @Test
    func bootstrap_recordsTheDay() async {
        let recorded = LockIsolated(0)
        let store = TestStore(
            initialState: AppReducer.State(),
            reducer: { AppReducer() },
            withDependencies: {
                // bootstrap also starts the tip observer, and an unstubbed TipJar.updates reports
                // an "Unimplemented" issue the moment it is called.
                $0.tipJar.updates = { AsyncStream { $0.finish() } }
                $0.tipInvitation.recordActiveDay = { recorded.withValue { $0 += 1 } }
            }
        )
        // bootstrap fans out into several never-ending observer effects alongside
        // runRecordActiveDay(), so this cannot await store.finish() - it would hang forever.
        store.exhaustivity = .off(showSkippedAssertions: true)

        let bootstrap = await store.send(.bootstrap)

        for _ in 1 ... 200 where recorded.value == 0 {
            try? await Task.sleep(for: .milliseconds(5))
        }

        await bootstrap.cancel()

        #expect(recorded.value == 1)
    }

    // Every foreground counts, including one with no server selected: someone between servers is
    // still using the app, and didBecomeActive's server guard would otherwise swallow the count.
    @Test
    func didBecomeActive_withoutAServer_stillRecordsTheDay() async {
        let recorded = LockIsolated(0)
        let store = TestStore(initialState: AppReducer.State()) {
            AppReducer()
        } withDependencies: {
            $0.tipInvitation.recordActiveDay = { recorded.withValue { $0 += 1 } }
        }
        store.exhaustivity = .off

        await store.send(.didBecomeActive).finish()

        #expect(recorded.value == 1)
    }

    @Test
    func didBecomeActive_withAServer_recordsTheDay() async {
        let recorded = LockIsolated(0)
        let store = TestStore(
            initialState: AppReducer.State(main: .testValue())
        ) {
            AppReducer()
        } withDependencies: {
            $0.tipInvitation.recordActiveDay = { recorded.withValue { $0 += 1 } }
        }
        store.exhaustivity = .off

        await store.send(.didBecomeActive).finish()

        #expect(recorded.value == 1)
    }

    // The inbox and the document list run the same reducer, so both have to route.
    @Test
    func tipInvitationTapped_fromTheInbox_opensTheTipList() async {
        let store = TestStore(
            initialState: AppReducer.State(main: .testValue(selectedTab: .inbox))
        ) {
            AppReducer()
        }
        store.exhaustivity = .off

        // openTipList is sent back into the store rather than applied inline, so the path mutation
        // only lands once that follow-up action has been processed.
        await store.send(.main(.inbox(.delegate(.tipInvitationTapped))))
        await store.receive(\.main.settingList.openTipList)

        #expect(store.state.main?.selectedTab == .settings)
        #expect(store.state.main?.settingList.path.count == 1)
    }

    @Test
    func tipInvitationTapped_fromTheDocumentList_opensTheTipList() async {
        let store = TestStore(
            initialState: AppReducer.State(main: .testValue(selectedTab: .documents))
        ) {
            AppReducer()
        }
        store.exhaustivity = .off

        // openTipList is sent back into the store rather than applied inline, so the path mutation
        // only lands once that follow-up action has been processed.
        await store.send(.main(.documentList(.delegate(.tipInvitationTapped))))
        await store.receive(\.main.settingList.openTipList)

        #expect(store.state.main?.selectedTab == .settings)
        #expect(store.state.main?.settingList.path.count == 1)
    }
}
