import Components
import SwiftUI

// Driven by `allCases` so a new section reaches the document detail toolbar and the row's context
// menu at once, without either of them naming the sections.
struct DocumentViewerMenu: View {

    var body: some View {
        Menu {
            ForEach(DocumentViewerSection.allCases, id: \.self) { section in
                Button {
                    sectionTapped(section)
                } label: {
                    Label(section.localized, systemImage: section.systemImage)
                }
            }
        } label: {
            Label(.view, systemImage: "doc.text")
        }
    }

    let sectionTapped: (DocumentViewerSection) -> Void
}

#Preview {
    Menu("Document") {
        DocumentViewerMenu { _ in }
    }
}
