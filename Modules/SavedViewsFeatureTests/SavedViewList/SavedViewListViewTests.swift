@testable import SavedViewsFeature

import ComposableArchitecture
import SwiftUI
import Testing
import TestSupport

@MainActor
@Suite(
    .dependencies {
        $0.getSavedViews.execute = { _ in [] }
    },
    .snapshots(record: .environment),
    .tags(.snapshotTests)
)
struct SavedViewListViewTests {

    @Test
    func testSnapshot() async throws {
        assertSnapshot(
            of: SavedViewListView(
                store: Store(
                    initialState: .testValue(savedViews: .previewValue),
                    reducer: {
                        SavedViewListReducer()
                    }
                )
            ),
            as: .image(layout: .device(config: .iPhone12))
        )

        assertSnapshot(
            of: SavedViewListView(
                store: Store(
                    initialState: .testValue(),
                    reducer: {
                        SavedViewListReducer()
                    }
                )
            ),
            as: .image(layout: .device(config: .iPhone12)),
            named: "empty"
        )
    }
}
