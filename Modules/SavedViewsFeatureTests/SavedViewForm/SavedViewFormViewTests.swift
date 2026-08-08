@testable import SavedViewsFeature

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
struct SavedViewFormViewTests {

    @Test
    func testSnapshot() async throws {
        assertSnapshot(
            of: ScrollView {
                SavedViewFormView(
                    store: Store(
                        initialState: .testValue(
                            id: .init(1),
                            input: .testValue()
                        ),
                        reducer: {
                            SavedViewFormReducer()
                        }
                    )
                )
            }
            .background(Color.m3Surface),
            as: .image(layout: .device(config: .iPhone12))
        )

        assertSnapshot(
            of: ScrollView {
                SavedViewFormView(
                    store: Store(
                        initialState: .testValue(),
                        reducer: {
                            SavedViewFormReducer()
                        }
                    )
                )
            }
            .background(Color.m3Surface),
            as: .image(layout: .device(config: .iPhone12)),
            named: "add"
        )

        assertSnapshot(
            of: ScrollView {
                SavedViewFormView(
                    store: Store(
                        initialState: .testValue(
                            id: .init(1),
                            input: .testValue()
                        ),
                        reducer: {
                            SavedViewFormReducer()
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
