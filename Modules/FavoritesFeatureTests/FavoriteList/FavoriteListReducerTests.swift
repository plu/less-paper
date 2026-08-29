@testable import FavoritesFeature

import ApiInterface
import ComposableArchitecture
import DocumentsFeature
import Foundation
import SwiftSharing
import Testing

@MainActor
@Suite(.dependencies())
struct FavoriteListReducerTests {

    @Test
    func test_searchFiltersOnTitle() async {
        let server = Server.testValue(id: "search-filters-on-title")

        @Shared(.favorites(server))
        var favorites: IdentifiedArrayOf<FavoriteDocument> = [
            .testValue(document: .testValue(content: nil, id: 1, title: "Invoice")),
            .testValue(document: .testValue(content: nil, id: 2, title: "Warranty")),
        ]

        let store = TestStore(initialState: FavoriteListReducer.State(server: server)) {
            FavoriteListReducer()
        }

        await store.send(\.binding.searchText, "inv") {
            $0.searchText = "inv"
            $0.rows.remove(id: 2)
        }

        #expect(store.state.rows.map(\.id) == [1])
    }

    @Test
    func test_refreshReportsItsResult() async {
        let server = Server.testValue(id: "refresh-reports-its-result")

        @Shared(.favorites(server))
        var favorites: IdentifiedArrayOf<FavoriteDocument> = [
            .testValue(document: .testValue(id: 1))
        ]

        let store = TestStore(initialState: FavoriteListReducer.State(server: server)) {
            FavoriteListReducer()
        } withDependencies: {
            $0.refreshFavorites.execute = { _, _ in FavoriteRefreshResult(updated: 1) }
        }

        await store.send(.view(.onRefresh)) { $0.isRefreshing = true }
        await store.receive(\.refreshResult) { $0.isRefreshing = false }
    }

    @Test
    func test_aRowShowsTheLiveDocumentWhenTheCacheHasOne() async {
        let server = Server.testValue(id: "row-shows-the-live-document")

        @Shared(.favorites(server))
        var favorites: IdentifiedArrayOf<FavoriteDocument> = [
            .testValue(document: .testValue(id: 1, title: "Stored"))
        ]
        @Shared(.documents(server))
        var cache: IdentifiedArrayOf<Document> = [
            .testValue(id: 1, title: "Edited")
        ]

        let store = TestStore(initialState: FavoriteListReducer.State(server: server)) {
            FavoriteListReducer()
        }

        #expect(store.state.rows[id: 1]?.document.title == "Edited")
    }

    @Test
    func test_aRowFallsBackToTheStoredDocumentWhenTheCacheHasNone() async {
        let server = Server.testValue(id: "row-falls-back-to-the-stored-document")

        @Shared(.favorites(server))
        var favorites: IdentifiedArrayOf<FavoriteDocument> = [
            .testValue(document: .testValue(id: 1, title: "Stored"))
        ]

        let store = TestStore(initialState: FavoriteListReducer.State(server: server)) {
            FavoriteListReducer()
        }

        #expect(store.state.rows[id: 1]?.document.title == "Stored")
    }

    // A swipe on a row, or a document favorited from another tab, writes the shared store rather
    // than this reducer's state. The observer started by `onAppear` is what carries that back, so
    // the list does not have to wait for its next appearance to show it.
    @Test
    func test_aFavoritesChangeRebuildsTheRows() async {
        let server = Server.testValue(id: "favorites-change-rebuilds-the-rows")

        @Shared(.favorites(server))
        var favorites: IdentifiedArrayOf<FavoriteDocument> = [
            .testValue(document: .testValue(id: 1)),
            .testValue(document: .testValue(id: 2)),
        ]

        let store = TestStore(initialState: FavoriteListReducer.State(server: server)) {
            FavoriteListReducer()
        }

        $favorites.withLock { _ = $0.remove(id: 2) }

        // What the observer delivers once the store has changed.
        await store.send(.favoritesChanged(favorites)) {
            $0.rows.remove(id: 2)
        }

        #expect(store.state.rows.map(\.id) == [1])
    }

    // The detail screen is the network screen, run against the record. Every fetch it makes is
    // counted here, not a chosen few: someone adding a call to that screen will not be thinking
    // about this tab, and without this assertion their change compiles, passes every other test,
    // and only fails once there is no connection.
    //
    // It opens the detail and each of the viewer's four sections, which between them reach
    // downloadDocument, getDocument, getNotes, getDocumentMetadata and getDocumentsByIds.
    @Test
    func test_theDetailScreenReadsFromTheStoreRatherThanTheNetwork() async throws {
        let server = Server.testValue(id: "detail-reads-from-the-store")
        let note = Note.testValue()
        let networkCalls = LockIsolated(0)

        let pdfURL = URL.temporaryDirectory.appending(component: "\(UUID().uuidString).pdf")
        try Data("%PDF-1.4".utf8).write(to: pdfURL)
        defer { try? FileManager.default.removeItem(at: pdfURL) }

        // A document-link field is what makes the custom fields section resolve anything at all;
        // with no such field it never asks, and the section would pass by doing nothing.
        @Shared(.customFields(server))
        var customFields: IdentifiedArrayOf<CustomField> = [
            .testValue(dataType: .documentLink, id: 1)
        ]

        let document = Document.testValue(
            customFields: [.testValue(field: 1, value: .array([.number(8)]))],
            id: 7
        )

        @Shared(.favorites(server))
        var favorites: IdentifiedArrayOf<FavoriteDocument> = [
            .testValue(document: document, metadata: .testValue(), notes: [note]),
            .testValue(document: .testValue(id: 8, title: "Linked")),
        ]

        let store = TestStore(initialState: FavoriteListReducer.State(server: server)) {
            FavoriteListReducer()
        } withDependencies: {
            $0.downloadDocument.execute = { _, _ in
                networkCalls.withValue { $0 += 1 }
                return Data()
            }
            $0.favoritesStore.pdfURL = { _, _ in pdfURL }
            $0.getDocument.execute = { _, _ in
                networkCalls.withValue { $0 += 1 }
                return .testValue()
            }
            $0.getDocumentMetadata.execute = { _, _ in
                networkCalls.withValue { $0 += 1 }
                return .testValue()
            }
            $0.getDocumentsByIds.execute = { _, _ in
                networkCalls.withValue { $0 += 1 }
                return []
            }
            $0.getNotes.execute = { _, _ in
                networkCalls.withValue { $0 += 1 }
                return []
            }
        }
        store.exhaustivity = .off

        let favorite = try #require(favorites[id: 7])
        await store.send(.rows(.element(id: 7, action: .delegate(.open(favorite)))))
        await store.send(.path(.element(id: 0, action: .documentDetail(.view(.onAppear)))))

        for section in DocumentViewerSection.allCases {
            await store.send(.path(.element(
                id: 0,
                action: .documentDetail(.view(.viewButtonTapped(section)))
            )))
            await store.send(.path(.element(
                id: 0,
                action: .documentDetail(.destination(.presented(.documentViewer(.view(.onAppear)))))
            )))
            await store.send(.path(.element(
                id: 0,
                action: .documentDetail(.destination(.presented(.documentViewer(.customFields(.view(.onAppear))))))
            )))
            await store.send(.path(.element(
                id: 0,
                action: .documentDetail(.destination(.presented(.documentViewer(.metadata(.view(.onAppear))))))
            )))
            await store.send(.path(.element(
                id: 0,
                action: .documentDetail(.destination(.presented(.documentViewer(.notes(.view(.onAppear))))))
            )))
        }

        await store.finish()

        #expect(networkCalls.value == 0)
    }
}
