@testable import DocumentsFeature

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
struct DocumentFormViewTests {

    @Test
    func testSnapshot() async throws {
        assertSnapshot(
            of: DocumentFormView(
                store: Store(
                    initialState: DocumentFormReducer.State.testValue(),
                    reducer: {
                        DocumentFormReducer()
                    }
                )
            ),
            as: .image(layout: .device(config: .iPhone12))
        )
    }

    @Test
    func testSnapshot_content() async throws {
        assertSnapshot(
            of: DocumentFormView(
                store: Store(
                    initialState: DocumentFormReducer.State.testValue(
                        content: "Some invoice, and all the rest of the OCR text the server holds.",
                        section: .content
                    ),
                    reducer: {
                        DocumentFormReducer()
                    }
                )
            ),
            as: .image(layout: .device(config: .iPhone12)),
            named: "content"
        )
    }

    @Test
    func testSnapshot_contentLoading() async throws {
        // The stub never returns, so the section stays in its loading state for the capture.
        withDependencies {
            $0.getDocument.execute = { _, _ in
                try await Task.sleep(for: .seconds(60))
                return .testValue()
            }
        } operation: {
            assertSnapshot(
                of: DocumentFormView(
                    store: Store(
                        initialState: DocumentFormReducer.State.testValue(section: .content),
                        reducer: {
                            DocumentFormReducer()
                        }
                    )
                ),
                as: .image(layout: .device(config: .iPhone12)),
                named: "contentLoading"
            )
        }
    }

    @Test
    func testSnapshot_contentError() async throws {
        assertSnapshot(
            of: DocumentFormView(
                store: Store(
                    initialState: DocumentFormReducer.State.testValue(
                        loadError: "The request timed out.",
                        section: .content
                    ),
                    reducer: {
                        DocumentFormReducer()
                    }
                )
            ),
            as: .image(layout: .device(config: .iPhone12)),
            named: "contentError"
        )
    }

    @Test
    func testSnapshot_notes() async throws {
        assertSnapshot(
            of: DocumentFormView(
                store: Store(
                    initialState: DocumentFormReducer.State.testValue(
                        notes: [.testValue()],
                        section: .notes
                    ),
                    reducer: {
                        DocumentFormReducer()
                    }
                )
            ),
            as: .image(layout: .device(config: .iPhone12)),
            named: "notes"
        )
    }
}
