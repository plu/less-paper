@testable import TagsFeature

import ComposableArchitecture
import DesignTokens
import SwiftUI
import Testing
import TestSupport

@MainActor
@Suite(
    .snapshots(record: .environment),
    .tags(.snapshotTests)
)
struct TagFormViewTests {

    @Test
    func testSnapshot() async throws {
        assertSnapshot(
            of: ScrollView {
                TagFormView(
                    store: Store(
                        initialState: .testValue(),
                        reducer: {
                            TagFormReducer()
                        }
                    )
                )
            }
            .background(Color.m3Surface),
            as: .image(layout: .device(config: .iPhone12))
        )

        assertSnapshot(
            of: ScrollView {
                TagFormView(
                    store: Store(
                        initialState: .testValue(tag: .testValue(matchingAlgorithm: .allWords)),
                        reducer: {
                            TagFormReducer()
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
