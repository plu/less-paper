@testable import SettingsFeature

import ApiInterface
import ComposableArchitecture
import Foundation
import SwiftUI
import Testing
import TestSupport

@MainActor
@Suite(
    .snapshots(record: .environment),
    .tags(.snapshotTests)
)
struct FavoriteSettingsViewTests {

    @Test
    func testSnapshot_populated() async throws {
        assertSnapshot(
            of: view(totalByteCount: 8_421_376),
            as: .image(layout: .device(config: .iPhone12)),
            named: "populated"
        )
    }

    // Nothing stored yet reads as "Zero KB" rather than as an empty screen, which is a state worth
    // having a reference for: this screen has no empty view of its own.
    @Test
    func testSnapshot_empty() async throws {
        assertSnapshot(
            of: view(totalByteCount: 0),
            as: .image(layout: .device(config: .iPhone12)),
            named: "empty"
        )
    }

    // Both buttons are disabled while a redownload or a remove runs, and only one of them shows the
    // spinner. A reference is the cheapest way to keep that true.
    @Test
    func testSnapshot_working() async throws {
        assertSnapshot(
            of: view(isWorking: true, totalByteCount: 8_421_376),
            as: .image(layout: .device(config: .iPhone12)),
            named: "working"
        )
    }

    // In a NavigationStack because that is how the screen is reached, and the title is part of it.
    // `totalByteCount` is stubbed to the state's own value so the `onAppear` reload, which may or
    // may not land before the image is taken, cannot change what is rendered.
    private func view(isWorking: Bool = false, totalByteCount: Int) -> some View {
        NavigationStack {
            FavoriteSettingsView(
                store: Store(
                    initialState: FavoriteSettingsReducer.State(
                        server: .testValue(),
                        isWorking: isWorking,
                        totalByteCount: totalByteCount
                    ),
                    reducer: { FavoriteSettingsReducer() },
                    withDependencies: {
                        $0.favoritesStore.totalByteCount = { _ in totalByteCount }
                    }
                )
            )
        }
    }
}
