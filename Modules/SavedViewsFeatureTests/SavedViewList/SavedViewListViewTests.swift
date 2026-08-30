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
            of: NavigationStack { SavedViewListView(
                store: Store(
                    initialState: .testValue(savedViews: .previewValue),
                    reducer: {
                        SavedViewListReducer()
                    }
                )
            )
            },
            as: .image(layout: .device(config: .iPhone12))
        )

        assertSnapshot(
            of: NavigationStack { SavedViewListView(
                store: Store(
                    initialState: .testValue(),
                    reducer: {
                        SavedViewListReducer()
                    }
                )
            )
            },
            as: .image(layout: .device(config: .iPhone12)),
            named: "empty"
        )
    }

    // Dark mode: `m3SurfaceContainerLowest` and the default list row background are both white in
    // light mode, so a row that never sets `listRowBackground` only shows up against dark.
    @Test
    func testSnapshot_darkMode() async throws {
        assertSnapshot(
            of: NavigationStack { SavedViewListView(
                store: Store(
                    initialState: .testValue(savedViews: .previewValue),
                    reducer: {
                        SavedViewListReducer()
                    }
                )
            )
            },
            as: .image(
                layout: .device(config: .iPhone12),
                traits: .init(userInterfaceStyle: .dark)
            )
        )
    }
}
