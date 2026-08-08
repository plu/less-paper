@testable import SavedViewsFeature

import ApiInterface
import ComposableArchitecture
import SwiftUI
import Testing
import TestSupport

@MainActor
@Suite(
    .dependencies(),
    .snapshots(record: .environment),
    .tags(.snapshotTests)
)
struct SavedViewRowViewTests {

    @Test
    func testSnapshot() async throws {
        assertSnapshot(
            of: row(showInSidebar: false, showOnDashboard: false),
            as: .image(layout: .device(config: .iPhone12)),
            named: "neither"
        )

        assertSnapshot(
            of: row(showInSidebar: true, showOnDashboard: false),
            as: .image(layout: .device(config: .iPhone12)),
            named: "sidebar"
        )

        assertSnapshot(
            of: row(showInSidebar: false, showOnDashboard: true),
            as: .image(layout: .device(config: .iPhone12)),
            named: "dashboard"
        )

        assertSnapshot(
            of: row(showInSidebar: true, showOnDashboard: true),
            as: .image(layout: .device(config: .iPhone12)),
            named: "both"
        )
    }

    private func row(showInSidebar: Bool, showOnDashboard: Bool) -> some View {
        List {
            SavedViewRowView(
                store: Store(
                    initialState: .testValue(
                        savedView: .testValue(
                            showInSidebar: showInSidebar,
                            showOnDashboard: showOnDashboard
                        )
                    ),
                    reducer: {
                        SavedViewRowReducer()
                    }
                )
            )
        }
    }
}
