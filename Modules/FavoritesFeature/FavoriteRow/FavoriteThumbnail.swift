import PDFKit
import SwiftUI

struct FavoriteThumbnail: View {

    var body: some View {
        if let image {
            Image(uiImage: image).resizable().aspectRatio(contentMode: .fit)
        } else {
            // The file is gone or is not a PDF. The row still has to lay out.
            Image(systemName: "doc").resizable().aspectRatio(contentMode: .fit)
        }
    }

    let url: URL
    let size: CGSize

    private var image: UIImage? {
        guard let page = PDFDocument(url: url)?.page(at: 0) else { return nil }
        return page.thumbnail(of: size, for: .mediaBox)
    }
}
