@testable import TipsFeature

import ComposableArchitecture
import Dependencies
import SwiftUI
import Testing
import TestSupport

@MainActor
@Suite(
    .dependencies(),
    .snapshots(record: .environment),
    .tags(.snapshotTests)
)
struct TipListViewTests {

    private static let products = [
        TipProduct(displayName: "Small tip", displayPrice: "€5.00", tip: .small),
        TipProduct(displayName: "Medium tip", displayPrice: "€10.00", tip: .medium),
        TipProduct(displayName: "Large tip", displayPrice: "€25.00", tip: .large),
    ]

    @Test
    func testSnapshot_loaded() async throws {
        assertSnapshot(
            of: NavigationStack {
                TipListView(
                    store: Store(
                        initialState: .init(isLoading: false, products: Self.products),
                        reducer: { TipListReducer() }
                    )
                )
            },
            as: .image(layout: .device(config: .iPhone12))
        )
    }

    @Test
    func testSnapshot_loading() async throws {
        // The stub never returns, so `onAppear`'s fetch stays in flight for the capture.
        withDependencies {
            $0.tipJar.products = {
                try await Task.sleep(for: .seconds(60))
                return []
            }
        } operation: {
            assertSnapshot(
                of: NavigationStack {
                    TipListView(
                        store: Store(
                            initialState: .init(),
                            reducer: { TipListReducer() }
                        )
                    )
                },
                as: .image(layout: .device(config: .iPhone12))
            )
        }
    }

    @Test
    func testSnapshot_purchasing() async throws {
        assertSnapshot(
            of: NavigationStack {
                TipListView(
                    store: Store(
                        initialState: .init(isLoading: false, products: Self.products, purchasingTip: .medium),
                        reducer: { TipListReducer() }
                    )
                )
            },
            as: .image(layout: .device(config: .iPhone12))
        )
    }

    @Test
    func testSnapshot_unavailable() async throws {
        assertSnapshot(
            of: NavigationStack {
                TipListView(
                    store: Store(
                        initialState: .init(isLoading: false, loadFailed: true),
                        reducer: { TipListReducer() }
                    )
                )
            },
            as: .image(layout: .device(config: .iPhone12))
        )
    }
}
