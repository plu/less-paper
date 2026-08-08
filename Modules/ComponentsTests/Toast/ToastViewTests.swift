@testable import Components

import SwiftUI
import Testing
import TestSupport

@MainActor
@Suite(
    .snapshots(record: .environment),
    .tags(.snapshotTests)
)
struct ToastViewTests {

    @Test
    func testSnapshot() async throws {
        let text = "Lorem Ipsum is simply dummy text of the printing and typesetting industry. Lorem Ipsum has been the industry's standard dummy text ever since the 1500s, when an unknown printer took a galley of type and scrambled it to make a type specimen book."

        assertSnapshot(
            of: VStack {
                ToastView(toast: .success(text))
                ToastView(toast: .error(text))
            }.padding(),
            as: .image(layout: .device(config: .iPhone12))
        )
    }
}
