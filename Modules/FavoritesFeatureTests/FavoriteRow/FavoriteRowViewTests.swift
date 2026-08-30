@testable import FavoritesFeature

import ApiInterface
import ComposableArchitecture
import Foundation
import SwiftUI
import Testing
import TestSupport
import UIKit

@MainActor
@Suite(
    // The image is handed to the row directly, so this path only keys the `.task` that a synchronous
    // snapshot never runs. It has to resolve, not to point at anything.
    .dependencies { $0.favoritesStore.pdfURL = { id, _ in URL(filePath: "/favorites/\(id).pdf") } },
    .snapshots(record: .environment),
    .tags(.snapshotTests)
)
struct FavoriteRowViewTests {

    // The reference that has to match DocumentRowViewTests. A favorite row shipped looking nothing
    // like a document row because the thumbnail renders in a `.task`, which a synchronous snapshot
    // never waits for — so every other reference shows the placeholder. This one hands the image in
    // and captures the row as it actually appears.
    @Test
    func testSnapshot_withThumbnail() async throws {
        let url = URL.temporaryDirectory.appending(component: "\(UUID().uuidString).pdf")
        try singlePagePDF().write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        let image = try #require(await FavoriteThumbnail.render(url: url, size: imageSize))

        assertSnapshot(
            of: row(renderedThumbnail: image),
            as: .image(layout: .fixed(width: 390, height: 220)),
            named: "with-thumbnail"
        )
    }

    // The placeholder is what a row shows before its render lands, and it must be the same dim fill
    // a document row shows while its thumbnail loads.
    @Test
    func testSnapshot_beforeTheThumbnailRenders() async throws {
        assertSnapshot(
            of: row(renderedThumbnail: nil),
            as: .image(layout: .fixed(width: 390, height: 220)),
            named: "placeholder"
        )
    }

    private let imageSize = CGSize(width: 134, height: 190)

    private func row(renderedThumbnail: UIImage?) -> some View {
        List {
            FavoriteRowView(
                store: Store(
                    initialState: FavoriteRowReducer.State(
                        favorite: .testValue(document: .testValue(id: 1, title: "Invoice")),
                        server: .testValue(id: "favorite-row-view-tests")
                    ),
                    reducer: { FavoriteRowReducer() }
                ),
                renderedThumbnail: renderedThumbnail
            )
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
            .listRowSeparator(.hidden)
            .padding(.x3)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private func singlePagePDF() -> Data {
        let bounds = CGRect(x: 0, y: 0, width: 612, height: 792)
        return UIGraphicsPDFRenderer(bounds: bounds).pdfData { context in
            context.beginPage()
            UIColor.white.setFill()
            UIBezierPath(rect: bounds).fill()
            UIColor.black.setFill()
            UIBezierPath(rect: bounds.insetBy(dx: 120, dy: 240)).fill()
        }
    }
}
