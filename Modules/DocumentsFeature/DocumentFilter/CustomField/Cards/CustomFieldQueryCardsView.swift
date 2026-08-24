import ApiInterface
import Components
import ComposableArchitecture
import SwiftUI

@ViewAction(for: CustomFieldQueryCardsReducer.self)
struct CustomFieldQueryCardsView: View {
    var body: some View {
        Sheet {
            SheetHeader(title: .customFields, left: closeButton)
        } content: {
            CustomFieldQueryCardView(
                depth: 0,
                fields: store.fields,
                onViewAction: { send($0) },
                path: [],
                query: store.query,
                state: store.state
            )
        }
        .sheet(
            item: $store.scope(state: \.editor, action: \.editor)
        ) { store in
            CustomFieldQueryAtomEditorView(store: store)
                .presentationDetents([.sheet])
        }
    }

    @Bindable
    var store: StoreOf<CustomFieldQueryCardsReducer>

    @ViewBuilder
    private func closeButton() -> some View {
        SheetCloseButton {
            send(.closeButtonTapped)
        }
    }
}
