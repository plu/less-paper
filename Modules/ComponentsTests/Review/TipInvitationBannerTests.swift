@testable import Components

import SwiftUI
import Testing
import TestSupport

@MainActor
@Suite(
    .testDependencies(),
    .snapshots(record: .environment),
    .tags(.snapshotTests)
)
struct TipInvitationBannerTests {

    @Test
    func testSnapshot() async throws {
        assertSnapshot(
            of: banner(),
            as: .image(layout: .device(config: .iPhone12))
        )
    }

    @Test
    func testSnapshot_darkMode() async throws {
        assertSnapshot(
            of: banner(),
            as: .image(
                layout: .device(config: .iPhone12),
                traits: .init(userInterfaceStyle: .dark)
            )
        )
    }

    // The message is the longest string in the module, and a row that truncates or clips its own
    // decline wording is worse than no row. German is longer still but cannot be snapshotted - no
    // unit snapshot test here renders another locale - so the largest text size stands in for it.
    @Test
    func testSnapshot_accessibilityLarge() async throws {
        assertSnapshot(
            of: banner(),
            as: .image(
                layout: .device(config: .iPhone12),
                traits: .init(preferredContentSizeCategory: .accessibilityLarge)
            )
        )
    }

    private func banner() -> some View {
        TipInvitationBanner(tapped: {}, dismissed: {})
            .padding(.x3)
            .background(Color.m3SurfaceContainerLowest)
    }
}
