@testable import AppFeature

import ApiInterface
import ComposableArchitecture
import SwiftUI
import Testing
import TestSupport

@MainActor
@Suite(
    .dependencies {
        $0.updateCache.execute = { _ in }
    },
    .snapshots(record: .environment),
    .tags(.snapshotTests)
)
struct MainViewTests {
    @Test
    func testSnapshot_settings() async throws {
        assertSnapshot(
            of: MainView(
                store: Store(
                    initialState: .testValue(selectedTab: .settings),
                    reducer: {
                        MainReducer()
                    }
                )
            ),
            as: .image(layout: .device(config: .iPhone12))
        )
    }
}
