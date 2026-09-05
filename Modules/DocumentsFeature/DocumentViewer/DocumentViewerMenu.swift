import Components
import SwiftUI

// Driven by `allCases` so a new section reaches the document detail toolbar and the row's context
// menu at once, without either of them naming the sections. `sections` defaults to `allCases` for
// that reason too — the document detail toolbar is the one caller that narrows it, to drop Notes
// without `view_note`.
struct DocumentViewerMenu: View {

    var body: some View {
        Menu {
            ForEach(sections, id: \.self) { section in
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

    var sections = DocumentViewerSection.allCases

    let sectionTapped: (DocumentViewerSection) -> Void
}

#Preview {
    Menu("Document") {
        DocumentViewerMenu { _ in }
    }
}
