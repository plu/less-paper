import ApiInterface
import Components
import ComposableArchitecture
import DesignTokens
import PermissionsFeature
import SwiftUI

@ViewAction(for: SavedViewFormReducer.self)
public struct SavedViewFormView: View {

    public var body: some View {
        Sheet {
            SheetHeader(
                title: store.savedViewId == nil ? .createSavedView : .editSavedView,
                left: {
                    SheetCloseButton {
                        send(.closeButtonTapped)
                    }
                }
            )
        } content: {
            VStack(spacing: .x4) {
                sectionPicker()
                switch store.section {
                case .form:
                    formSection()
                case .permissions:
                    permissionsSection()
                }
            }
        } bottom: {
            buttons()
        }
    }

    public init(store: StoreOf<SavedViewFormReducer>) {
        self.store = store
    }

    @Bindable
    public var store: StoreOf<SavedViewFormReducer>

    @ViewBuilder
    private func buttons() -> some View {
        AdaptiveStack {
            Button {
                send(.cancelButtonTapped)
            } label: {
                Text(.cancel)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.secondary())
            .frame(maxWidth: .infinity)

            Button {
                send(.saveButtonTapped)
            } label: {
                Text(.save)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.primary(isLoading: $store.isSaving))
        }
    }

    @ViewBuilder
    private func formSection() -> some View {
        nameField()

        showInSidebarField()

        showOnDashboardField()
    }

    @ViewBuilder
    private func nameField() -> some View {
        Field(.name) {
            TextField(String(localized: .name), text: $store.input.name.value)
                .textFieldStyle(.plain)
        }
        .state($store.input.name)
    }

    @ViewBuilder
    private func permissionsSection() -> some View {
        PermissionsFormView(
            store: store.scope(
                state: \.permissionsForm,
                action: \.permissionsForm
            )
        )
    }

    @ViewBuilder
    private func sectionPicker() -> some View {
        Picker("", selection: $store.section) {
            ForEach(SavedViewFormSection.allCases, id: \.self) {
                Text($0.description)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
    }

    @ViewBuilder
    private func showInSidebarField() -> some View {
        Field {
            Toggle(isOn: $store.input.showInSidebar, label: {
                Text(.showInSidebar)
                    .lineLimit(1)
            })
            .accessibilityLabel(.showInSidebar)
            .onTapGesture { store.input.showInSidebar.toggle() }
        }
        .tint(Color.m3Primary)
    }

    @ViewBuilder
    private func showOnDashboardField() -> some View {
        Field {
            Toggle(isOn: $store.input.showOnDashboard, label: {
                Text(.showOnDashboard)
                    .lineLimit(1)
            })
            .accessibilityLabel(.showOnDashboard)
            .onTapGesture { store.input.showOnDashboard.toggle() }
        }
        .tint(Color.m3Primary)
    }
}

#Preview {
    SavedViewFormView(
        store: Store(
            initialState: .testValue(),
            reducer: {
                SavedViewFormReducer()
            }
        )
    )
}
