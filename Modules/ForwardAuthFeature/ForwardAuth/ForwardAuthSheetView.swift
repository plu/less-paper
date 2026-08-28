import ApiInterface
import SwiftUI

public struct ForwardAuthSheetView: View {

    let redirect: ForwardAuthRedirect

    let onFinished: () -> Void

    let onCancel: () -> Void

    public init(
        redirect: ForwardAuthRedirect,
        onFinished: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.redirect = redirect
        self.onFinished = onFinished
        self.onCancel = onCancel
    }

    public var body: some View {
        NavigationStack {
            ForwardAuthWebView(redirect: redirect, onFinished: onFinished)
                .navigationBarTitleDisplayMode(.inline)
                .navigationTitle(redirect.url.host() ?? "")
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button(action: onCancel) {
                            Label(.close, systemImage: "xmark.circle")
                        }
                    }
                }
        }
    }
}
