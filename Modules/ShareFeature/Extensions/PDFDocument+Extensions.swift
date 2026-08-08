import PDFKit
import UIKit

extension PDFDocument {

    var firstPageImage: UIImage? {
        guard let page = page(at: 0) else {
            return nil
        }
        let bounds = page.bounds(for: .trimBox)
        let aspectRatio = bounds.width / bounds.height
        let height: CGFloat = 154 * 2
        let size = CGSize(width: height * aspectRatio, height: height)
        return page.thumbnail(of: size, for: .trimBox)
    }
}
