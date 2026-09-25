@testable import DocumentsFeature

import ApiInterface
import ComposableArchitecture
import SwiftUI
import Testing
import TestSupport

@MainActor
@Suite(
    .testDependencies(),
    .snapshots(record: .environment),
    .tags(.snapshotTests)
)
struct DocumentDetailViewTests {

    @Test
    func testSnapshot_success() async throws {
        let data = try Data.testValue()
        let url = URL.testValue()

        assertSnapshot(
            of: DocumentDetailView(
                store: Store(
                    initialState: DocumentDetailReducer.State.testValue(
                        downloadResult: .success(data: data, url: url)
                    ),
                    reducer: {
                        DocumentDetailReducer()
                    }
                )
            ),
            as: .image(layout: .device(config: .iPhone12))
        )
    }

    @Test
    func testSnapshot_failure() async throws {
        assertSnapshot(
            of: DocumentDetailView(
                store: Store(
                    initialState: DocumentDetailReducer.State.testValue(
                        downloadResult: .failure("Something went wrong")
                    ),
                    reducer: {
                        DocumentDetailReducer()
                    }
                )
            ),
            as: .image(layout: .device(config: .iPhone12))
        )
    }

    // Bare, DocumentDetailView has no NavigationStack ancestor, so SwiftUI drops the whole toolbar
    // — these two are what would actually catch the edit button reappearing on an offline snapshot.
    //
    // Their references show a blank page under a ghosted bar, and that is not a broken recording.
    // Wrapping the view in a NavigationStack here while it states its own display mode leaves the
    // host with no window to draw into, so the capture is of an unrealised hierarchy — neither a
    // wait nor drawHierarchyInKeyWindow changes it, and the real app renders the page normally.
    // What survives is the toolbar, which is the only thing these two are for: `···` plus `Edit`
    // above, `···` alone below. The page itself is covered by testSnapshot_success.
    @Test
    func testSnapshot_toolbar_editable() async throws {
        let data = try Data.testValue()
        let url = URL.testValue()

        assertSnapshot(
            of: NavigationStack {
                DocumentDetailView(
                    store: Store(
                        initialState: DocumentDetailReducer.State.testValue(
                            downloadResult: .success(data: data, url: url)
                        ),
                        reducer: {
                            DocumentDetailReducer()
                        }
                    )
                )
            },
            as: .image(layout: .device(config: .iPhone12))
        )
    }

    @Test
    func testSnapshot_toolbar_offlineSnapshot() async throws {
        let data = try Data.testValue()
        let url = URL.testValue()
        let server = Server.testValue()
        let document = ApiInterface.Document.testValue()

        @Shared(.offlineDocuments(server)) var favorites: IdentifiedArrayOf<OfflineDocument> = [
            .testValue(document: document)
        ]

        assertSnapshot(
            of: NavigationStack {
                DocumentDetailView(
                    store: Store(
                        initialState: DocumentDetailReducer.State.testValue(
                            document: document,
                            downloadResult: .success(data: data, url: url),
                            isOfflineSnapshot: true,
                            server: server
                        ),
                        reducer: {
                            DocumentDetailReducer()
                        }
                    )
                )
            },
            as: .image(layout: .device(config: .iPhone12))
        )
    }
}
