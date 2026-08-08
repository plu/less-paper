@testable import StoragePathsFeature

import ComposableArchitecture
import SwiftUI
import Testing
import TestSupport

@MainActor
@Suite(
    .snapshots(record: .environment),
    .tags(.snapshotTests)
)
struct StoragePathFormViewTests {

    @Test
    func testSnapshot() async throws {
        assertSnapshot(
            of: ScrollView {
                StoragePathFormView(
                    store: Store(
                        initialState: .testValue(),
                        reducer: {
                            StoragePathFormReducer()
                        }
                    )
                )
            }
            .background(Color.m3Surface),
            as: .image(layout: .device(config: .iPhone12))
        )

        assertSnapshot(
            of: ScrollView {
                StoragePathFormView(
                    store: Store(
                        initialState: .testValue(storagePath: .testValue(matchingAlgorithm: .allWords)),
                        reducer: {
                            StoragePathFormReducer()
                        }
                    )
                )
            }
            .environment(\.sizeCategory, .accessibilityLarge)
            .frame(width: 375)
            .background(Color.m3Surface),
            as: .image(layout: .device(config: .iPhone12)),
            named: "accessibilityLarge"
        )
    }
}
