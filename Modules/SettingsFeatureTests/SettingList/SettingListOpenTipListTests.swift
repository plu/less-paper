@testable import SettingsFeature

import ApiInterface
import ComposableArchitecture
import PdfPasswordsFeature
import TagsFeature
import Testing
import TestSupport

@MainActor
@Suite(
    .testDependencies()
)
struct SettingListOpenTipListTests {

    @Test
    func openTipList_pushesTheTipList() async {
        let store = TestStore(
            initialState: SettingListReducer.State(server: .testValue())
        ) {
            SettingListReducer()
        }
        store.exhaustivity = .off

        await store.send(.openTipList)

        #expect(store.state.path.count == 1)
        #expect(store.state.path.first?.tipList != nil)
    }

    // Replaced rather than appended. The invitation is once-ever, so its one job beyond the ask is
    // to leave the user at a place whose Back button reveals the Settings row the tip jar lives
    // behind - and appending onto an already-deep stack buries exactly that.
    @Test
    func openTipList_fromADeepStack_replacesIt() async {
        var state = SettingListReducer.State(server: .testValue())
        state.path.append(.pdfPasswordList(PdfPasswordListReducer.State()))
        state.path.append(.tagList(TagListReducer.State(server: .testValue())))

        let store = TestStore(initialState: state) {
            SettingListReducer()
        }
        store.exhaustivity = .off

        await store.send(.openTipList)

        #expect(store.state.path.count == 1)
        #expect(store.state.path.first?.tipList != nil)
    }
}
