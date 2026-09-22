import ComposableArchitecture
import DesignTokens
import SwiftUI

struct DocumentListStatusBarView: View {

    let store: StoreOf<DocumentListReducer>

    // Hidden while search results are showing: the counts describe the document fetch underneath,
    // so the pill would report "12 of 340 loaded" over a list of seven tags.
    var body: some View {
        if !store.isSearching, !store.documents.isEmpty, store.totalNumberOfDocuments > 0 {
            if store.documentSelection.isActive {
                Text(.numberOfSelectedDocuments(
                    selected: store.documentSelection.selectedDocuments.count,
                    total: store.totalNumberOfDocuments
                ))
                .capsule(
                    backgroundColor: .m3Primary,
                    font: .footnote,
                    foregroundColor: .m3OnPrimary
                )
                .padding(.x3)
            } else {
                Text(.numberOfLoadedDocuments(
                    loaded: store.documents.count,
                    total: store.totalNumberOfDocuments
                ))
                .capsule(
                    backgroundColor: .m3Primary,
                    font: .footnote,
                    foregroundColor: .m3OnPrimary
                )
                .padding(.x3)
            }
        }
    }
}
