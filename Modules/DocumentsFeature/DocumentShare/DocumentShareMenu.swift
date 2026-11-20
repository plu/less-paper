import ApiInterface
import SwiftUI

// Driven from one place so a change reaches the document detail toolbar and the row's context menu
// at once, the same reason DocumentOpenMenu exists.
//
// The document itself is passed in rather than built here: detail shares a file it has already
// downloaded, while a row has to download one first, and those are different views.
struct DocumentShareMenu<Document: View>: View {

    var body: some View {
        Menu {
            document()

            // The file above, pointers to it below. A link is worth sharing whether or not the
            // document has come down, which is why the links are not inside that condition.
            Divider()

            if let url = DeepLink.appURL(server: server, route: .documentDetail(documentId)) {
                ShareLink(item: url) {
                    Label(.appLink, systemImage: "candybarphone")
                }
            }

            if let url = DeepLink.webURL(server: server, route: .documentDetail(documentId)) {
                ShareLink(item: url) {
                    Label(.webLink, systemImage: "globe")
                }
            }

            if let shareLinks {
                Button(action: shareLinks) {
                    Label(.shareLink, systemImage: "link.badge.plus")
                }
            }
        } label: {
            Label(.share, systemImage: "square.and.arrow.up")
        }
    }

    let documentId: ApiInterface.Document.Id

    let server: Server

    // nil when the user may not create share links, which leaves the item out altogether.
    var shareLinks: (() -> Void)?

    @ViewBuilder
    let document: () -> Document
}

#Preview {
    Menu("Document") {
        DocumentShareMenu(documentId: 42, server: .testValue(), shareLinks: {}) {
            Button("Document") {}
        }
    }
}
