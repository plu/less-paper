@testable import CorrespondentsFeature

import ComposableArchitecture
import SwiftUI
import Testing
import TestSupport

@MainActor
@Suite(
    .dependencies {
        $0.getCorrespondents.execute = { _ in [] }
    },
    .snapshots(record: .environment),
    .tags(.snapshotTests)
)
struct CorrespondentListViewTests {

    @Test
    func testSnapshot() async throws {
        assertSnapshot(
            of: NavigationStack { CorrespondentListView(
                store: Store(
                    initialState: .testValue(correspondents: .previewValue),
                    reducer: {
                        CorrespondentListReducer()
                    }
                )
            )
            },
            as: .image(layout: .device(config: .iPhone12))
        )

        assertSnapshot(
            of: NavigationStack { CorrespondentListView(
                store: Store(
                    initialState: .testValue(),
                    reducer: {
                        CorrespondentListReducer()
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
            of: NavigationStack { CorrespondentListView(
                store: Store(
                    initialState: .testValue(correspondents: .previewValue),
                    reducer: {
                        CorrespondentListReducer()
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
