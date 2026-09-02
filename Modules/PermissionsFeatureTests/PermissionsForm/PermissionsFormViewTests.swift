@testable import PermissionsFeature

import ComposableArchitecture
import DesignTokens
import SwiftUI
import Testing
import TestSupport

@MainActor
@Suite(
    .dependencies {
        $0.getPermissions.execute = { _, _ in .testValue() }
    },
    .snapshots(record: .environment),
    .tags(.snapshotTests)
)
struct PermissionsFormViewTests {

    @Test
    func testSnapshot() async throws {
        assertSnapshot(
            of: ScrollView {
                PermissionsFormView(
                    store: Store(
                        initialState: .testValue(),
                        reducer: {
                            PermissionsFormReducer()
                        }
                    )
                )
            }
            .background(Color.m3Surface),
            as: .image(layout: .device(config: .iPhone12))
        )

        assertSnapshot(
            of: ScrollView {
                PermissionsFormView(
                    store: Store(
                        initialState: .testValue(),
                        reducer: {
                            PermissionsFormReducer()
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
