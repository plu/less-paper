import SwiftUI
import UIKit

public struct ShareSheet: UIViewControllerRepresentable {

    public func makeUIViewController(context _: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    public func updateUIViewController(_: UIActivityViewController, context _: Context) {}

    public init(url: URL) {
        self.url = url
    }

    private let url: URL
}
