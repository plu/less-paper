@testable import OfflineFeature

import ApiInterface
import ComposableArchitecture
import Foundation
import SwiftSharing
import SwiftUI
import Testing
import TestSupport

@MainActor
@Suite(
    // No PDF behind the thumbnails: the references are about the list, and a real file would make
    // them depend on PDFKit's rendering rather than on this view.
    .testDependencies { $0.offlineStore.pdfURL = { id, _ in URL(filePath: "/offline/\(id).pdf") } },
    .snapshots(record: .environment),
    .tags(.snapshotTests)
)
struct OfflineListViewTests {

    @Test
    func testSnapshot_populated() async throws {
        let server = Server.testValue(id: "snapshot-populated")

        @Shared(.offlineDocuments(server))
        var offlineDocuments: IdentifiedArrayOf<OfflineDocument> = [
            .testValue(document: .testValue(id: 1, title: "Invoice")),
            .testValue(document: .testValue(id: 2, title: "Warranty")),
        ]

        assertSnapshot(
            of: view(server: server),
            as: .image(layout: .device(config: .iPhone12)),
            named: "populated"
        )
    }

    @Test
    func testSnapshot_empty() async throws {
        let server = Server.testValue(id: "snapshot-empty")

        assertSnapshot(
            of: view(server: server),
            as: .image(layout: .device(config: .iPhone12)),
            named: "empty"
        )
    }

    // A search that matches nothing is not the same nothing as having no offline documents, and the
    // two states are one `else if` apart — which is what makes a reference worth having for each.
    @Test
    func testSnapshot_noSearchResults() async throws {
        let server = Server.testValue(id: "snapshot-no-search-results")

        @Shared(.offlineDocuments(server))
        var offlineDocuments: IdentifiedArrayOf<OfflineDocument> = [
            .testValue(document: .testValue(content: nil, id: 1, title: "Invoice"))
        ]

        let store = Store(
            initialState: OfflineListReducer.State(server: server),
            reducer: { OfflineListReducer() }
        )
        store.send(.binding(.set(\.searchText, "nothing matches this")))

        assertSnapshot(
            of: OfflineListView(store: store),
            as: .image(layout: .device(config: .iPhone12)),
            named: "no-search-results"
        )
    }

    // The badge only shows on an offline document the last refresh could not find on the server,
    // which is the one row state no other reference covers.
    @Test
    func testSnapshot_unavailable() async throws {
        let server = Server.testValue(id: "snapshot-unavailable")

        @Shared(.offlineDocuments(server))
        var offlineDocuments: IdentifiedArrayOf<OfflineDocument> = [
            .testValue(document: .testValue(id: 1, title: "Invoice"), isUnavailable: true)
        ]

        assertSnapshot(
            of: view(server: server),
            as: .image(layout: .device(config: .iPhone12)),
            named: "unavailable"
        )
    }

    private func view(server: Server) -> some View {
        OfflineListView(
            store: Store(
                initialState: OfflineListReducer.State(server: server),
                reducer: { OfflineListReducer() }
            )
        )
    }
}
