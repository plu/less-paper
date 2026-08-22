@testable import DocumentsFeature

import ApiInterface
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
struct DocumentNotesViewTests {

    @Test
    func testSnapshot() async throws {
        assertSnapshot(
            of: view(
                state: .testValue(notes: [
                    .testValue(),
                    .testValue(
                        created: .testValue().addingTimeInterval(3600),
                        id: 2,
                        note: "Filed under Q3. Chase the supplier about the missing VAT line before the quarter closes.",
                        user: .testValue(id: 2, username: "johannes")
                    ),
                ])
            ),
            as: .image(layout: .device(config: .iPhone12))
        )
    }

    @Test
    func testSnapshot_empty() async throws {
        assertSnapshot(
            of: view(state: .testValue(notes: [])),
            as: .image(layout: .device(config: .iPhone12)),
            named: "empty"
        )
    }

    @Test
    func testSnapshot_loading() async throws {
        // The stub never returns, so the section stays in its loading state for the capture.
        withDependencies {
            $0.getNotes.execute = { _, _ in
                try await Task.sleep(for: .seconds(60))
                return []
            }
        } operation: {
            assertSnapshot(
                of: view(state: .testValue()),
                as: .image(layout: .device(config: .iPhone12)),
                named: "loading"
            )
        }
    }

    @Test
    func testSnapshot_error() async throws {
        assertSnapshot(
            of: view(state: .testValue(loadError: "The request timed out.")),
            as: .image(layout: .device(config: .iPhone12)),
            named: "error"
        )
    }

    // Read-only drops the swipe action from every row. The swipe itself cannot be captured, so
    // this pins the rest of the row against the editable snapshot above.
    @Test
    func testSnapshot_readOnly() async throws {
        assertSnapshot(
            of: view(state: .testValue(notes: [.testValue()]), isReadOnly: true),
            as: .image(layout: .device(config: .iPhone12)),
            named: "readOnly"
        )
    }

    private func view(
        state: DocumentNotesReducer.State,
        isReadOnly: Bool = false
    ) -> some View {
        DocumentNotesView(
            store: Store(
                initialState: state,
                reducer: {
                    DocumentNotesReducer()
                }
            ),
            isReadOnly: isReadOnly
        )
    }
}
