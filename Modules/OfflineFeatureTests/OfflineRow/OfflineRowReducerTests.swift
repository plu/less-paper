@testable import OfflineFeature

import ApiInterface
import ComposableArchitecture
import Foundation
import Testing
import TestSupport

@MainActor
@Suite(
    .testDependencies()
)
struct OfflineRowReducerTests {

    @Test
    func test_removeFromOfflineRemovesTheDocument() async {
        let removed = LockIsolated<Document.Id?>(nil)
        let offlineDocument = OfflineDocument.testValue(document: .testValue(id: 7))

        let store = TestStore(
            initialState: OfflineRowReducer.State(offlineDocument: offlineDocument, server: .testValue())
        ) {
            OfflineRowReducer()
        } withDependencies: {
            $0.removeOfflineDocument.execute = { id, _ in removed.setValue(id) }
        }

        await store.send(.view(.removeFromOfflineButtonTapped))

        #expect(removed.value == 7)
    }

    @Test
    func test_tappingTheRowAsksToOpenIt() async {
        let offlineDocument = OfflineDocument.testValue(document: .testValue(id: 7))

        let store = TestStore(
            initialState: OfflineRowReducer.State(offlineDocument: offlineDocument, server: .testValue())
        ) {
            OfflineRowReducer()
        }

        await store.send(.view(.rowTapped))
        await store.receive(\.delegate.open)
    }
}
