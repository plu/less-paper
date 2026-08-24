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
        .sheet(item: editorBinding, content: editor(_:))
    }

    @Bindable
    var store: StoreOf<CustomFieldQueryCardsReducer>

    private var editorBinding: Binding<CustomFieldQueryCardsReducer.State.Editor?> {
        Binding(
            get: { store.editor },
            set: { editor in
                guard editor == nil else {
                    return
                }
                send(.editorDismissed)
            }
        )
    }

    @ViewBuilder
    private func editor(_ editor: CustomFieldQueryCardsReducer.State.Editor) -> some View {
        CustomFieldQueryAtomEditorView(
            editor: editor,
            fields: store.fields,
            onViewAction: { send($0) }
        )
        .presentationDetents([.sheet])
    }

    @ViewBuilder
    private func closeButton() -> some View {
        SheetCloseButton {
            send(.closeButtonTapped)
        }
    }
}
