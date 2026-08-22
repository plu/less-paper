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
struct DocumentViewerViewTests {

    @Test
    func testSnapshot_content() async throws {
        assertSnapshot(
            of: view(state: .testValue(
                document: .testValue(content: content),
                hasLoadedContent: true
            )),
            as: .image(layout: .device(config: .iPhone12))
        )
    }

    @Test
    func testSnapshot_content_loading() async throws {
        // The stub never returns, so the section stays in its loading state for the capture.
        withDependencies {
            $0.getDocument.execute = { _, _ in
                try await Task.sleep(for: .seconds(60))
                return .testValue()
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
    func testSnapshot_content_error() async throws {
        assertSnapshot(
            of: view(state: .testValue(loadError: "The request timed out.")),
            as: .image(layout: .device(config: .iPhone12)),
            named: "error"
        )
    }

    @Test
    func testSnapshot_content_empty() async throws {
        assertSnapshot(
            of: view(state: .testValue(
                document: .testValue(content: ""),
                hasLoadedContent: true
            )),
            as: .image(layout: .device(config: .iPhone12)),
            named: "empty"
        )
    }

    @Test
    func testSnapshot_notes() async throws {
        assertSnapshot(
            of: view(state: .testValue(
                hasLoadedContent: true,
                notes: [
                    .testValue(),
                    .testValue(
                        created: .testValue().addingTimeInterval(3600),
                        id: 2,
                        note: "Filed under Q3. Chase the supplier about the missing VAT line before the quarter closes.",
                        user: .testValue(id: 2, username: "johannes")
                    ),
                ],
                section: .notes
            )),
            as: .image(layout: .device(config: .iPhone12)),
            named: "notes"
        )
    }

    @Test
    func testSnapshot_metadata() async throws {
        assertSnapshot(
            of: view(state: .testValue(
                hasLoadedContent: true,
                metadata: .testValue(),
                section: .metadata
            )),
            as: .image(layout: .device(config: .iPhone12)),
            named: "metadata"
        )
    }

    @Test
    func testSnapshot_darkMode() async throws {
        assertSnapshot(
            of: view(state: .testValue(
                document: .testValue(content: content),
                hasLoadedContent: true
            )),
            as: .image(
                layout: .device(config: .iPhone12),
                traits: .init(userInterfaceStyle: .dark)
            ),
            named: "darkMode"
        )
    }

    private let content = """
    INVOICE 2026-0184

    Acme Supplies Ltd
    18 Harbour Road, Bristol

    Item            Qty     Net
    Copy paper A4    12   48.00
    Toner cartridge   2   79.90

    Net total             127.90
    VAT 20%                25.58
    Due                   153.48
    """

    private func view(state: DocumentViewerReducer.State) -> some View {
        DocumentViewerView(
            store: Store(
                initialState: state,
                reducer: {
                    DocumentViewerReducer()
                }
            )
        )
    }
}
