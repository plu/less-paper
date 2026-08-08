@testable import StoragePathsFeature

import ComposableArchitecture
import SwiftUI
import Testing
import TestSupport

@MainActor
@Suite(
    .dependencies {
        $0.getStoragePaths.execute = { _ in [] }
    },
    .snapshots(record: .environment),
    .tags(.snapshotTests)
)
struct StoragePathListViewTests {

    @Test
    func testSnapshot() async throws {
        assertSnapshot(
            of: StoragePathListView(
                store: Store(
                    initialState: .testValue(storagePaths: .previewValue),
                    reducer: {
                        StoragePathListReducer()
                    }
                )
            ),
            as: .image(layout: .device(config: .iPhone12))
        )

        assertSnapshot(
            of: StoragePathListView(
                store: Store(
                    initialState: .testValue(),
                    reducer: {
                        StoragePathListReducer()
                    }
                )
            ),
            as: .image(layout: .device(config: .iPhone12)),
            named: "empty"
        )
    }
}
