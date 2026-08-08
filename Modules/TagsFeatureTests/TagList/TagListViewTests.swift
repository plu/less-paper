@testable import TagsFeature

import ComposableArchitecture
import SwiftUI
import Testing
import TestSupport

@MainActor
@Suite(
    .dependencies {
        $0.getTags.execute = { _ in [] }
    },
    .snapshots(record: .environment),
    .tags(.snapshotTests)
)
struct TagListViewTests {

    @Test
    func testSnapshot() async throws {
        assertSnapshot(
            of: TagListView(
                store: Store(
                    initialState: .testValue(tags: .previewValue),
                    reducer: {
                        TagListReducer()
                    }
                )
            ),
            as: .image(layout: .device(config: .iPhone12))
        )

        assertSnapshot(
            of: TagListView(
                store: Store(
                    initialState: .testValue(),
                    reducer: {
                        TagListReducer()
                    }
                )
            ),
            as: .image(layout: .device(config: .iPhone12)),
            named: "empty"
        )
    }
}
