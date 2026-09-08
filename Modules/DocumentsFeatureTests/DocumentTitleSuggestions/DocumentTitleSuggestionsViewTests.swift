@testable import DocumentsFeature

import ComposableArchitecture
import Dependencies
import Intelligence
import SwiftUI
import Testing
import TestSupport

@MainActor
@Suite(
    .dependencies(),
    .snapshots(record: .environment),
    .tags(.snapshotTests)
)
struct DocumentTitleSuggestionsViewTests {

    @Test
    func testSnapshot() async throws {
        assertSnapshot(
            of: view(
                state: .testValue(suggestions: [
                    "Electricity bill — August 2024",
                    "Stadtwerke München invoice 84.20 EUR",
                    "Utilities statement, August 2024",
                ])
            ),
            as: .image(layout: .device(config: .iPhone12))
        )
    }

    // Two rows in and still running: the state a user actually sees for most of the generation.
    @Test
    func testSnapshot_streaming() async throws {
        assertSnapshot(
            of: view(
                state: .testValue(
                    isGenerating: true,
                    suggestions: ["Electricity bill — August 2024", "Stadtwerke München invoice"]
                )
            ),
            as: .image(layout: .device(config: .iPhone12)),
            named: "streaming"
        )
    }

    @Test
    func testSnapshot_generating() async throws {
        assertSnapshot(
            of: view(state: .testValue(isGenerating: true)),
            as: .image(layout: .device(config: .iPhone12)),
            named: "generating"
        )
    }

    @Test
    func testSnapshot_error() async throws {
        assertSnapshot(
            of: view(state: .testValue(error: String(localized: .titleSuggestionFailed))),
            as: .image(layout: .device(config: .iPhone12)),
            named: "error"
        )
    }

    private func view(state: DocumentTitleSuggestionsReducer.State) -> some View {
        DocumentTitleSuggestionsView(
            store: Store(
                initialState: state,
                reducer: {
                    DocumentTitleSuggestionsReducer()
                }
            )
        )
    }
}
