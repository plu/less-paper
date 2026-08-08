@testable import AppFeature

import ApiInterface
import ComposableArchitecture
import ServersFeature
import SwiftSharing
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
struct AppViewTests {
    @Test
    func testSnapshot_noSelectedServer() async throws {
        assertSnapshot(
            of: AppView(
                store: Store(
                    initialState: AppReducer.State(),
                    reducer: {
                        AppReducer()
                    }
                )
            ),
            as: .image(layout: .device(config: .iPhone12))
        )
    }
}
