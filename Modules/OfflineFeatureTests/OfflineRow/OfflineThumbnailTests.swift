@testable import OfflineFeature

import Foundation
import Testing
import TestSupport
import UIKit

@MainActor
@Suite(
    .testDependencies()
)
struct OfflineThumbnailTests {

    // Every snapshot suite points `pdfURL` at a path with no file behind it, so all four references
    // show the placeholder. This is the one test that puts real bytes there.
    @Test
    func test_aStoredPdfRendersItsFirstPage() async throws {
        let url = URL.temporaryDirectory.appending(component: "\(UUID().uuidString).pdf")
        try singlePagePDF().write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        let image = await OfflineThumbnail.render(url: url, size: size)

        #expect(image != nil)
    }

    @Test
    func test_aMissingFileRendersNothing() async {
        let url = URL.temporaryDirectory.appending(component: "\(UUID().uuidString).pdf")

        let image = await OfflineThumbnail.render(url: url, size: size)

        #expect(image == nil)
    }

    private let size = CGSize(width: 134, height: 190)

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
