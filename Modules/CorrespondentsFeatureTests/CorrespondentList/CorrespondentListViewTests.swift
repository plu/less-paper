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
            of: CorrespondentListView(
                store: Store(
                    initialState: .testValue(correspondents: .previewValue),
                    reducer: {
                        CorrespondentListReducer()
                    }
                )
            ),
            as: .image(layout: .device(config: .iPhone12))
        )

        assertSnapshot(
            of: CorrespondentListView(
                store: Store(
                    initialState: .testValue(),
                    reducer: {
                        CorrespondentListReducer()
                    }
                )
            ),
            as: .image(layout: .device(config: .iPhone12)),
            named: "empty"
        )
    }
}
