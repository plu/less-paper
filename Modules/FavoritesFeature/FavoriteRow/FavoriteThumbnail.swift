import PDFKit
import SwiftUI

struct FavoriteThumbnail: View {

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image).resizable().aspectRatio(contentMode: .fit)
            } else {
                // Not rendered yet, or the file is gone or is not a PDF. The row lays out either way.
                Image(systemName: "doc").resizable().aspectRatio(contentMode: .fit)
            }
        }
        .task(id: FileVersion(url: url, storedAt: storedAt)) {
            image = await Self.render(url: url, size: size)
        }
    }

    let url: URL
    let size: CGSize
    let storedAt: Date

    // A refresh rewrites the same path, so keying the render on the url alone leaves page one of
    // the file that was replaced on screen. `storedAt` is what moves when the bytes are rewritten.
    private struct FileVersion: Equatable {
        let url: URL
        let storedAt: Date
    }

    @State private var image: UIImage?

    // Opening a PDF and rasterising a page is far too much to do while SwiftUI evaluates a body: as
    // a computed property it ran for every visible row on every frame of a scroll. Once per
    // appearance, off the main actor, into @State.
    static func render(url: URL, size: CGSize) async -> UIImage? {
        await Task.detached(priority: .userInitiated) {
            guard let page = PDFDocument(url: url)?.page(at: 0) else { return nil }
            return page.thumbnail(of: size, for: .mediaBox)
        }.value
    }
}
