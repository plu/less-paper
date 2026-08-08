@testable import ServersFeature

import ComposableArchitecture
import SwiftUI
import Testing
import TestSupport

@MainActor
@Suite(
    .snapshots(record: .environment),
    .tags(.snapshotTests)
)
struct ServerFormViewTests {

    @Test
    func testSnapshot() async throws {
        assertSnapshot(
            of: ScrollView {
                ServerFormView(
                    store: Store(
                        initialState: .testValue(
                            input: .testValue(url: .testValue(string: "http://localhost:8000"))
                        ),
                        reducer: {
                            ServerFormReducer()
                        }
                    )
                )
            }
            .background(Color.m3Surface),
            as: .image(layout: .device(config: .iPhone12))
        )

        assertSnapshot(
            of: ScrollView {
                ServerFormView(
                    store: Store(
                        initialState: .testValue(
                            input: .testValue(url: .testValue(string: "http://localhost:8000"))
                        ),
                        reducer: {
                            ServerFormReducer()
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

        var advancedState = ServerFormReducer.State.testValue(
            input: .testValue(
                headers: [
                    .testValue(id: "1", name: "Accept", value: "application/json; version=9"),
                    .testValue(id: "2", name: "X-Custom", value: "some-value")
                ],
                url: .testValue(string: "http://localhost:8000")
            )
        )
        advancedState.section = .advanced

        assertSnapshot(
            of: ScrollView {
                ServerFormView(
                    store: Store(
                        initialState: advancedState,
                        reducer: {
                            ServerFormReducer()
                        }
                    )
                )
            }
            .background(Color.m3Surface),
            as: .image(layout: .device(config: .iPhone12)),
            named: "advanced"
        )
    }
}
