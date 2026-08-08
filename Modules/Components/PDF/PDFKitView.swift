import PDFKit
import SwiftUI

public struct PDFKitView: UIViewRepresentable {

    public func makeUIView(context _: Context) -> PDFView {
        let view = PDFView(data: data)
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

private extension PDFView {

    convenience init(data: Data) {
        self.init()
        document = PDFDocument(data: data)
        minScaleFactor = scaleFactorForSizeToFit
        autoScales = true
    }
}
