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

    // Explicit cache, not a nil one: a nil cache fails open and renders everything, which would
    // make a "gated" snapshot identical to an ungated one and assert nothing.
    @Test
    func testSnapshot_toolbar_notesHidden() async throws {
        let data = try Data.testValue()
        let url = URL.testValue()
        let server = Server.testValue()

        @Shared(.permissions(server)) var permissions: [Permission]?
        @Shared(.currentUser(server)) var currentUser: User?
        $currentUser.withLock { $0 = .testValue(isSuperuser: false) }
        // changeDocument stays granted so canEdit — already covered by its own snapshot — is not
        // what moves here; view_note is the only permission this case withholds.
        $permissions.withLock { $0 = [.viewDocument, .changeDocument] }

        assertSnapshot(
            of: NavigationStack {
                DocumentDetailView(
                    store: Store(
                        initialState: DocumentDetailReducer.State.testValue(
                            downloadResult: .success(data: data, url: url),
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
