import Components
import ComposableArchitecture
import QuickLook
import SwiftUI

public extension View {

    // Everything a row action can open. Extracted so a list that is not the document list - the
    // Offline tab composes its own row - can offer the same swipe actions without any of them
    // silently doing nothing for want of somewhere to present.
    func documentRowDestinations(store: StoreOf<DocumentRowReducer>) -> some View {
        modifier(DocumentRowDestinations(store: store))
    }
}

private struct DocumentRowDestinations: ViewModifier {

    func body(content: Content) -> some View {
        content
            .quickLookPreview($store.quickLookPreview)
            .sheet(item: $store.shareItem) { item in
                ShareSheet(url: item.url)
            }
            .sheet(
                item: $store.scope(state: \.destination?.documentForm, action: \.destination.documentForm)
            ) { store in
                DocumentFormView(store: store)
                    .presentationDetents([.large])
            }
            .sheet(
                item: $store.scope(state: \.destination?.documentViewer, action: \.destination.documentViewer)
            ) { store in
                DocumentViewerView(store: store)
                    .presentationDetents([.large])
            }
    }

    @Bindable
    var store: StoreOf<DocumentRowReducer>
}
