@testable import DocumentTypesFeature

import ComposableArchitecture
import SwiftUI
import Testing
import TestSupport

@MainActor
@Suite(
    .snapshots(record: .environment),
    .tags(.snapshotTests)
)
struct DocumentTypeFormViewTests {

    @Test
    func testSnapshot() async throws {
        assertSnapshot(
            of: ScrollView {
                DocumentTypeFormView(
                    store: Store(
                        initialState: .testValue(),
                        reducer: {
                            DocumentTypeFormReducer()
                        }
                    )
                )
            }
            .background(Color.m3Surface),
            as: .image(layout: .device(config: .iPhone12))
        )

        assertSnapshot(
            of: ScrollView {
                DocumentTypeFormView(
                    store: Store(
                        initialState: .testValue(documentType: .testValue(matchingAlgorithm: .allWords)),
                        reducer: {
                            DocumentTypeFormReducer()
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
