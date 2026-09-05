@testable import DocumentsFeature

import ApiInterface
import ComposableArchitecture
import SwiftUI
import Testing
import TestSupport

@MainActor
@Suite(
    .dependencies(),
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
        let document = Document.testValue()

        @Shared(.favorites(server)) var favorites: IdentifiedArrayOf<FavoriteDocument> = [
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
