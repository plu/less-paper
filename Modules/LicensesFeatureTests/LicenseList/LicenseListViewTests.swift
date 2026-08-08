@testable import LicensesFeature

import ComposableArchitecture
import SwiftUI
import Testing
import TestSupport

@MainActor
@Suite(
    .snapshots(record: .environment),
    .tags(.snapshotTests)
)
struct LicenseListViewTests {

    @Test
    func testSnapshot() async throws {
        assertSnapshot(
            of: LicenseListView(
                store: Store(
                    initialState: .init(),
                    reducer: {
                        LicenseListReducer()
                    }
                )
            ),
            as: .image(layout: .device(config: .iPhone12))
        )
    }
}
