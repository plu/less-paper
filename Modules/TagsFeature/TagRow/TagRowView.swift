import ApiInterface
import Components
import ComposableArchitecture
import Dependencies
import DesignTokens
import SwiftUI

@ViewAction(for: TagRowReducer.self)
struct TagRowView: View {

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(store.tag.name).foregroundColor(Color.m3OnSurface)
                Group {
                    HStack {
                        if store.tag.isInboxTag {
                            Image(systemName: "tray")
                        }
                        Text(.numberOfDocuments(store.tag.documentCount))
                        Spacer()
                    }
                }
                .font(.caption)
                .foregroundColor(.m3Outline)
            }
            Spacer()
            Text(store.tag.color).tag(tag: store.tag, font: .footnote)
        }
        .accessibilityElement()
        .accessibilityValue([
            store.tag.name,
            String(localized: .numberOfDocuments(store.tag.documentCount))
        ].joined(separator: ", "))
        .listRowBackground(Color.m3SurfaceContainer)
        .opacity(store.isUpdating ? 0.5 : 1.0)
        .swipeActions(content: swipeActions)
    }

    var store: StoreOf<TagRowReducer>

    @ViewBuilder
    private func swipeActions() -> some View {
        if store.permissions.can(.changeTag) {
            Button {
                send(.editButtonTapped)
            } label: {
                Image(systemName: "square.and.pencil")
            }
            .accessibilityLabel(.editTag)
            .tint(.m3Primary)
        }

        if store.permissions.can(.deleteTag) {
            Button {
                send(.deleteButtonTapped)
            } label: {
                Image(systemName: "trash")
            }
            .accessibilityLabel(.deleteTag)
            .tint(.m3Error)
        }
    }
}

#Preview {
    List {
        TagRowView(
            store: Store(
                initialState: TagRowReducer.State(
                    server: .testValue(),
                    tag: .testValue()
                ),
                reducer: {
                    TagRowReducer()
                }
            )
        )
    }
}
