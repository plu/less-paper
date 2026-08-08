@testable import ShareFeature

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
struct ShareFormViewTests {

    @Test
    func testSnapshot() async throws {
        assertSnapshot(
            of: ShareFormView(
                store: Store(
                    initialState: .testValue(),
                    reducer: {
                        ShareFormReducer()
                    }
                )
            ),
            as: .image(layout: .device(config: .iPhone12))
        )

        @Shared(.servers)
        var servers: IdentifiedArrayOf<Server>

        $servers.withLock {
            $0 = [
                .testValue(id: "1"),
                .testValue(id: "2")
            ]
        }

        assertSnapshot(
            of: ShareFormView(
                store: Store(
                    initialState: .testValue(),
                    reducer: {
                        ShareFormReducer()
                    }
                )
            ),
            as: .image(layout: .device(config: .iPhone12)),
            named: "multiple_servers"
        )

        assertSnapshot(
            of: ShareFormView(
                store: Store(
                    initialState: .testValue(),
                    reducer: {
                        ShareFormReducer()
                    }
                )
            )
            .environment(\.sizeCategory, .accessibilityLarge)
            .frame(width: 375),
            as: .image(layout: .device(config: .iPhone12)),
            named: "accessibilityLarge"
        )
    }
}
