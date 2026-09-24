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

    @Test
    func testSnapshot_withAction() async throws {
        assertSnapshot(
            of: VStack {
                ToastView(
                    toast: .success("Removed 2 inbox tags"),
                    action: .init(title: "Undo") {}
                )
                ToastView(
                    toast: .error("Something went wrong"),
                    action: .init(title: "Retry") {}
                )
                // The button has to keep its width when the message runs long, rather than being
                // squeezed out by the text.
                ToastView(
                    toast: .success("Removed 2 inbox tags from a document with a rather long title"),
                    action: .init(title: "Undo") {}
                )
            }.padding(),
            as: .image(layout: .device(config: .iPhone12))
        )
    }
}
