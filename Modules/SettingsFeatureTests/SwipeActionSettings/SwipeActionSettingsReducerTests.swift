@testable import SettingsFeature

import Components
import ComposableArchitecture
import Foundation
import Testing
import TestSupport

@MainActor
@Suite(
    .testDependencies()
)
struct SwipeActionSettingsReducerTests {

    @Test
    func actionTapped_addsToTheEdge() async throws {
        let store = TestStore(initialState: SwipeActionSettingsReducer.State()) {
            SwipeActionSettingsReducer()
        }
        store.state.$settings.withLock { $0 = .init() }

        await store.send(.view(.actionTapped(screen: .inbox, edge: .leading, action: .share))) {
            $0.$settings.withLock { $0.inbox.leading = [.edit, .share] }
        }
    }

    @Test
    func actionTapped_removesOneAlreadyThere() async throws {
        let store = TestStore(initialState: SwipeActionSettingsReducer.State()) {
            SwipeActionSettingsReducer()
        }
        store.state.$settings.withLock { $0 = .init() }

        await store.send(.view(.actionTapped(screen: .inbox, edge: .leading, action: .edit))) {
            $0.$settings.withLock { $0.inbox.leading = [] }
        }
    }

    // A full swipe only fires the first action, so a third is a menu the user has to read.
    @Test
    func actionTapped_refusesAThirdActionOnAnEdge() async throws {
        let store = TestStore(initialState: SwipeActionSettingsReducer.State()) {
            SwipeActionSettingsReducer()
        }
        store.state.$settings.withLock {
            $0 = .init(inbox: .init(leading: [.edit, .share], trailing: []))
        }

        await store.send(.view(.actionTapped(screen: .inbox, edge: .leading, action: .preview)))

        #expect(store.state.settings.inbox.leading == [.edit, .share])
    }

    @Test
    func resetButtonTapped_restoresTheDefaults() async throws {
        let store = TestStore(initialState: SwipeActionSettingsReducer.State()) {
            SwipeActionSettingsReducer()
        }
        store.state.$settings.withLock {
            $0 = .init(
                documents: .init(leading: [], trailing: []),
                inbox: .init(leading: [], trailing: [])
            )
        }

        await store.send(.view(.resetButtonTapped)) {
            $0.$settings.withLock { $0 = DocumentSwipeActionSettings() }
        }
    }
}
