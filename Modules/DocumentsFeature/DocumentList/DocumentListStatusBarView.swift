import ComposableArchitecture
import DesignTokens
import SwiftUI

struct DocumentListStatusBarView: View {

    let store: StoreOf<DocumentListReducer>

    var body: some View {
        if !store.documents.isEmpty && store.totalNumberOfDocuments > 0 {
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
