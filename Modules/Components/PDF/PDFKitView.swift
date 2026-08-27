import PDFKit
import SwiftUI

public struct PDFKitView: UIViewRepresentable {

    public func makeUIView(context _: Context) -> PDFView {
        let view = FittingPDFView(data: data)
        view.accessibilityIdentifier = "PDF"
        view.backgroundColor = backgroundColor
        view.displayDirection = displayDirection
        return view
    }

    public func updateUIView(_: PDFView, context _: Context) {}

    public init(
        data: Data,
        displayDirection: PDFDisplayDirection = .vertical,
        backgroundColor: UIColor = .m3Surface
    ) {
        self.data = data
        self.displayDirection = displayDirection
        self.backgroundColor = backgroundColor
    }

    private let data: Data
    private let displayDirection: PDFDisplayDirection
    private let backgroundColor: UIColor
}

/// A `PDFView` that keeps its minimum scale in step with its size.
///
/// `scaleFactorForSizeToFit` is derived from the view's current bounds, so reading it in an
/// initialiser - before the view has ever been laid out - pins `minScaleFactor` to a fit for a size
/// the view never had. Whenever the real fit falls below that floor the page is clamped larger than
/// its container and cropped on every edge, which is what a split view column does: it is a
/// fraction of the width the view was created at.
///
/// On iPhone the container is the window, so the stale floor was close enough to be invisible.
private final class FittingPDFView: PDFView {

    override func layoutSubviews() {
        super.layoutSubviews()

        let fit = scaleFactorForSizeToFit
        guard fit > 0, fit != minScaleFactor else {
            return
        }

        minScaleFactor = fit
        // Only while PDFKit still owns the scale: a pinch clears autoScales, and re-fitting then
        // would undo the zoom the reader just asked for.
        if autoScales {
            scaleFactor = fit
        }
    }

    convenience init(data: Data) {
        self.init()
        document = PDFDocument(data: data)
        autoScales = true
    }
}
