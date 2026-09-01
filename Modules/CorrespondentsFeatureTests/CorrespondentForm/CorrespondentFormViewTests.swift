@testable import CorrespondentsFeature

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
struct CorrespondentFormViewTests {

    @Test
    func testSnapshot() async throws {
        assertSnapshot(
            of: ScrollView {
                CorrespondentFormView(
                    store: Store(
                        initialState: .testValue(),
                        reducer: {
                            CorrespondentFormReducer()
                        }
                    )
                )
            }
            .background(Color.m3Surface),
            as: .image(layout: .device(config: .iPhone12))
        )

        assertSnapshot(
            of: ScrollView {
                CorrespondentFormView(
                    store: Store(
                        initialState: .testValue(correspondent: .testValue(matchingAlgorithm: .allWords)),
                        reducer: {
                            CorrespondentFormReducer()
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
