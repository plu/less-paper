import PDFKit
import SwiftUI

@preconcurrency import VisionKit

public struct DocumentScannerView: UIViewControllerRepresentable {

    public init(completion: @escaping (Result<[URL], any Error>) -> Void) {
        self.completion = completion
    }

    public func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let documentCameraViewController = VNDocumentCameraViewController()
        documentCameraViewController.delegate = context.coordinator
        return documentCameraViewController
    }

    public func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}

    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    private let completion: (Result<[URL], any Error>) -> Void

    @Environment(\.dismiss)
    private var dismiss
}

public extension DocumentScannerView {

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let parent: DocumentScannerView

        init(_ parent: DocumentScannerView) {
            self.parent = parent
        }

        public func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFinishWith scan: VNDocumentCameraScan
        ) {
            let parent = self.parent
            DispatchQueue.global().async {
                let images = (0 ..< scan.pageCount).map(scan.imageOfPage(at:))
                let document = PDFDocument(images: images)
                let url = FileManager.default.temporaryDirectory
                    .appendingPathComponent("scan")
                    .appendingPathExtension("pdf")
                document.write(to: url)
                DispatchQueue.main.async {
                    parent.dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now().advanced(by: .milliseconds(400))) {
                        parent.completion(.success([url]))
                    }
                }
            }
        }

        public func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            let parent = self.parent
            DispatchQueue.main.async {
                parent.dismiss()
            }
        }

        public func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            let parent = self.parent
            DispatchQueue.main.async {
                parent.completion(.failure(error))
                parent.dismiss()
            }
        }
    }
}

extension PDFDocument {

    convenience init(images: [UIImage]) {
        self.init()
        for (index, image) in images.enumerated() {
            guard let page = PDFPage(image: image) else {
                continue
            }

            insert(page, at: index)
        }
    }
}
