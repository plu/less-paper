@testable import DiagnosticsFeature

import ComposableArchitecture
import Foundation
import Logging
import Testing

@MainActor
@Suite
struct DiagnosticsListReducerTests {

    @Test
    func test_onAppear_loadsEntriesAndFiles() async {
        let entry = LogEntry(date: .distantPast, level: .error, category: .api, message: "boom")
        let url = URL.temporaryDirectory.appending(path: "error.log")

        let store = TestStore(initialState: DiagnosticsListReducer.State()) {
            DiagnosticsListReducer()
        } withDependencies: {
            $0.log.entries = { [entry] }
            $0.log.fileURLs = { [url] }
        }

        await store.send(.view(.onAppear))
        await store.receive(\.entriesLoaded) {
            $0.entries = [entry]
            $0.fileURLs = [url]
            $0.isLoaded = true
        }
    }

    @Test
    func test_clear_doesNothingWhenTheConfirmationIsDeclined() async {
        let entry = LogEntry(date: .distantPast, level: .error, category: .api, message: "boom")
        let cleared = LockIsolated(false)

        let store = TestStore(
            initialState: DiagnosticsListReducer.State(entries: [entry], isLoaded: true)
        ) {
            DiagnosticsListReducer()
        } withDependencies: {
            $0.clearLogConfirmation.present = { false }
            $0.log.clear = { cleared.setValue(true) }
        }

        await store.send(.view(.clearButtonTapped))

        #expect(!cleared.value)
    }

    @Test
    func test_clear_emptiesTheLogWhenConfirmed() async {
        let entry = LogEntry(date: .distantPast, level: .error, category: .api, message: "boom")
        let cleared = LockIsolated(false)

        let store = TestStore(
            initialState: DiagnosticsListReducer.State(entries: [entry], isLoaded: true)
        ) {
            DiagnosticsListReducer()
        } withDependencies: {
            $0.clearLogConfirmation.present = { true }
            $0.log.clear = { cleared.setValue(true) }
        }

        await store.send(.view(.clearButtonTapped))
        await store.receive(\.entriesLoaded) {
            $0.entries = []
            $0.fileURLs = []
        }

        #expect(cleared.value)
    }
}
