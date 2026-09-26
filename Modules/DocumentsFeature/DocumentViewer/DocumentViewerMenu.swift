import Components
import SwiftUI

// Shows exactly the sections its caller passes; every caller narrows `DocumentViewerSection.allCases`
// through `DocumentViewerSection.visible`, which drops Notes and History the user cannot read.
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

    let sections: [DocumentViewerSection]

    let sectionTapped: (DocumentViewerSection) -> Void
}

#Preview {
    Menu("Document") {
        DocumentViewerMenu(sections: DocumentViewerSection.allCases) { _ in }
    }
}
