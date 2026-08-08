@testable import SettingsFeature

import ComposableArchitecture
import SwiftUI
import Testing
import TestSupport

@MainActor
@Suite(
    .snapshots(record: .environment),
    .tags(.snapshotTests)
)
struct SettingListViewTests {
    @Test
    func testSnapshot() async throws {
        assertSnapshot(
            of: SettingListView(
                store: Store(
                    initialState: .testValue(),
                    reducer: {
                        SettingListReducer()
                    }
                )
            ),
            as: .image(layout: .device(config: .iPhone12))
        )
    }
}
