@testable import SettingsFeature

import Components
import ComposableArchitecture
import Foundation
import SwiftUI
import Testing
import TestSupport

@MainActor
@Suite(
    .testDependencies(),
    .snapshots(record: .environment),
    .tags(.snapshotTests)
)
struct SwipeActionSettingsViewTests {

    @Test
    func testSnapshot_defaults() async throws {
        assertSnapshot(
            of: view(settings: .init()),
            as: .image(layout: .fixed(width: 390, height: 2400)),
            named: "defaults"
        )
    }

    // A full edge and an empty one in the same shot: the numbering has to read as an order, and an
    // edge with nothing on it has to look deliberate rather than broken.
    @Test
    func testSnapshot_fullAndEmptyEdges() async throws {
        assertSnapshot(
            of: view(settings: .init(
                documents: .init(leading: [], trailing: []),
                inbox: .init(leading: [.edit, .share], trailing: [.delete])
            )),
            as: .image(layout: .fixed(width: 390, height: 2400)),
            named: "fullAndEmptyEdges"
        )
    }

    private func view(settings: DocumentSwipeActionSettings) -> some View {
        let state = SwipeActionSettingsReducer.State()
        state.$settings.withLock { $0 = settings }
        return NavigationStack {
            SwipeActionSettingsView(
                store: Store(initialState: state) {
                    SwipeActionSettingsReducer()
                }
            )
        }
    }
}
