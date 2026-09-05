import ApiInterface
import Components
import ComposableArchitecture
import Dependencies
import DesignTokens
import SwiftUI

@ViewAction(for: CustomFieldRowReducer.self)
struct CustomFieldRowView: View {

    var body: some View {
        VStack(alignment: .leading) {
            Text(store.customField.name).foregroundColor(Color.m3OnSurface)
                .clipShape(Rectangle())
            Text(caption)
                .font(.caption)
                .foregroundColor(.m3Outline)
        }
        .accessibilityElement()
        .accessibilityValue([
            store.customField.name,
            caption
        ].joined(separator: ", "))
        .listRowBackground(Color.m3SurfaceContainer)
        .opacity(store.isUpdating ? 0.5 : 1.0)
        .swipeActions(content: swipeActions)
    }

    var store: StoreOf<CustomFieldRowReducer>

    private var caption: String {
        [
            store.customField.dataType.description,
            String(localized: .numberOfDocuments(store.customField.documentCount))
        ].joined(separator: " · ")
    }

    @ViewBuilder
    private func swipeActions() -> some View {
        if store.permissions.can(.changeCustomfield) {
            Button {
                send(.editButtonTapped)
            } label: {
                Image(systemName: "square.and.pencil")
            }
            .accessibilityLabel(.editCustomField)
            .tint(.m3Primary)
        }

        if store.permissions.can(.deleteCustomField) {
            Button {
                send(.deleteButtonTapped)
            } label: {
                Image(systemName: "trash")
            }
            .accessibilityLabel(.deleteCustomField)
            .tint(.m3Error)
        }
    }
}

#Preview {
    List {
        CustomFieldRowView(
            store: Store(
                initialState: CustomFieldRowReducer.State(
                    server: .testValue(),
                    customField: .testValue()
                ),
                reducer: {
                    CustomFieldRowReducer()
                }
            )
        )
    }
}
