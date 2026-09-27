import Components
import SwiftUI

// Shows exactly the sections its caller passes; every caller narrows `DocumentSheetSection.allCases`
// through `DocumentSheetSection.visible`. "Open" rather than "View" or "Edit": whether a section
// opens editable is the sheet's decision, made from the user's permissions, not the menu's.
struct DocumentOpenMenu: View {

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
            Label(.open, systemImage: "doc.text")
        }
    }

    let sections: [DocumentSheetSection]

    let sectionTapped: (DocumentSheetSection) -> Void
}

#Preview {
    Menu("Document") {
        DocumentOpenMenu(sections: DocumentSheetSection.allCases) { _ in }
    }
}
