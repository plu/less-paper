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
struct DocumentMetadataViewTests {

    @Test
    func testSnapshot() async throws {
        assertSnapshot(
            of: view(state: .testValue(metadata: .testValue())),
            as: .image(layout: .device(config: .iPhone12))
        )
    }

    // Six of the fourteen seeded documents have no archived copy, and the server sends the archive
    // fields as null rather than omitting them. The card has to disappear, not render empty.
    @Test
    func testSnapshot_withoutArchiveVersion() async throws {
        assertSnapshot(
            of: view(state: .testValue(metadata: .testValue(
                archiveChecksum: nil,
                archiveMediaFilename: nil,
                archiveSize: nil,
                hasArchiveVersion: false
            ))),
            as: .image(layout: .device(config: .iPhone12)),
            named: "withoutArchiveVersion"
        )
    }

    @Test
    func testSnapshot_empty() async throws {
        assertSnapshot(
            of: view(state: .testValue(metadata: .testValue(
                archiveChecksum: nil,
                archiveMediaFilename: nil,
                archiveSize: nil,
                hasArchiveVersion: false,
                lang: nil,
                mediaFilename: nil,
                originalChecksum: nil,
                originalFilename: nil,
                originalMimeType: nil,
                originalSize: nil
            ))),
            as: .image(layout: .device(config: .iPhone12)),
            named: "empty"
        )
    }

    @Test
    func testSnapshot_loading() async throws {
        // The stub never returns, so the section stays in its loading state for the capture.
        withDependencies {
            $0.getDocumentMetadata.execute = { _, _ in
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
    func testSnapshot_error() async throws {
        assertSnapshot(
            of: view(state: .testValue(loadError: "The request timed out.")),
            as: .image(layout: .device(config: .iPhone12)),
            named: "error"
        )
    }

    @Test
    func testSnapshot_darkMode() async throws {
        assertSnapshot(
            of: view(state: .testValue(metadata: .testValue())),
            as: .image(
                layout: .device(config: .iPhone12),
                traits: .init(userInterfaceStyle: .dark)
            ),
            named: "darkMode"
        )
    }

    private func view(state: DocumentMetadataReducer.State) -> some View {
        DocumentMetadataView(
            store: Store(
                initialState: state,
                reducer: {
                    DocumentMetadataReducer()
                }
            )
        )
    }
}
