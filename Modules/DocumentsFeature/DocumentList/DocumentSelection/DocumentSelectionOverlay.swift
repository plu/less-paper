import ApiInterface
import Components
import ComposableArchitecture
import SwiftUI

extension View {

    func documentSelectionOverlay(
        document: Document.Id,
        store: StoreOf<DocumentSelectionReducer>
    ) -> some View {
        modifier(
            DocumentSelectionOverlay(
                document: document,
                store: store
            )
        )
    }
}

private struct DocumentSelectionOverlay: ViewModifier {
    func body(content: Content) -> some View {
        Group {
            if store.selectedDocuments.contains(document) {
                HStack(spacing: .x2) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title)
                        .foregroundStyle(Color.m3Surface, Color.m3Primary)
                    content
                        .overlay(alignment: .topLeading) {
                            if store.selectedDocuments.contains(document) {
                                RoundedRectangle(cornerRadius: Constants.cornerRadius)
                                    .strokeBorder(Color.m3Primary, lineWidth: 2)
                            }
                        }
                        .toolbarVisibility(.hidden, for: .tabBar)
                }
            } else {
                content
            }
        }
        .highPriorityGesture(TapGesture().onEnded { _ in
            store.send(.documentTapped(document))
        }, isEnabled: store.isActive)
    }

    init(
        document: Document.Id,
        store: StoreOf<DocumentSelectionReducer>
    ) {
        self.document = document
        self.store = store
    }

    private let document: Document.Id

    @Bindable
    private var store: StoreOf<DocumentSelectionReducer>
}
