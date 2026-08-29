@testable import FavoritesFeature

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
    .dependencies { $0.favoritesStore.pdfURL = { id, _ in URL(filePath: "/favorites/\(id).pdf") } },
    .snapshots(record: .environment),
    .tags(.snapshotTests)
)
struct FavoriteListViewTests {

    @Test
    func testSnapshot_populated() async throws {
        let server = Server.testValue(id: "snapshot-populated")

        @Shared(.favorites(server))
        var favorites: IdentifiedArrayOf<FavoriteDocument> = [
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

    // The badge only shows on a favorite the last refresh could not find on the server, which is
    // the one row state no other reference covers.
    @Test
    func testSnapshot_unavailable() async throws {
        let server = Server.testValue(id: "snapshot-unavailable")

        @Shared(.favorites(server))
        var favorites: IdentifiedArrayOf<FavoriteDocument> = [
            .testValue(document: .testValue(id: 1, title: "Invoice"), isUnavailable: true)
        ]

        assertSnapshot(
            of: view(server: server),
            as: .image(layout: .device(config: .iPhone12)),
            named: "unavailable"
        )
    }

    private func view(server: Server) -> some View {
        FavoriteListView(
            store: Store(
                initialState: FavoriteListReducer.State(server: server),
                reducer: { FavoriteListReducer() }
            )
        )
    }
}
