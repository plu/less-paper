import Components
import DesignTokens
import PDFKit
import SwiftUI

// Presented exactly as `DocumentImage` presents a server thumbnail — filled to the box, cropped,
// over the same dim placeholder — because a favourite row sits beside document rows everywhere else
// in the app and any difference here reads as a different kind of row rather than a different
// source of picture.
struct FavoriteThumbnail: View {

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size.width, height: size.height)
                    .clipped()
            } else {
                // Not rendered yet, or the file is gone or is not a PDF. Either way the row keeps
                // its shape, and this is what a document row shows while its thumbnail loads.
                Color.m3SurfaceDim
                    .frame(width: size.width, height: size.height)
            }
        }
        .task(id: FileVersion(url: url, storedAt: storedAt)) {
            image = await Self.render(url: url, size: size)
        }
    }

    // The render happens in a `.task`, which never runs during a synchronous snapshot capture — so
    // without a way to seed the image, every reference shows the placeholder and the row's most
    // visible element is untestable. That is how a favorite row that looked nothing like a document
    // row reached a build. Previews use it too.
    init(url: URL, size: CGSize, storedAt: Date, renderedImage: UIImage? = nil) {
        self.url = url
        self.size = size
        self.storedAt = storedAt
        _image = State(initialValue: renderedImage)
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
            guard let page = PDFDocument(url: url)?.page(at: 0) else {
                return nil
            }
            return page.thumbnail(of: size, for: .mediaBox)
        }.value
    }
}
