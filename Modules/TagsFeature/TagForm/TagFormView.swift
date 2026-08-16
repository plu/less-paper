import ApiInterface
import Components
import ComposableArchitecture
import PermissionsFeature
import SwiftUI

@ViewAction(for: TagFormReducer.self)
public struct TagFormView: View {

    public var body: some View {
        Sheet {
            SheetHeader(
                title: store.tagId == nil ? .createTag : .editTag,
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

    public init(store: StoreOf<TagFormReducer>) {
        self.store = store
    }

    @Bindable
    public var store: StoreOf<TagFormReducer>

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
    private func colorField() -> some View {
        Field {
            ColorPicker(selection: $color, label: {
                Text(.color)
            })
        }
        .bind($store.input.color, to: $color)
    }

    @ViewBuilder
    private func formSection() -> some View {
        nameField()

        AdaptiveStack {
            colorField()
            isInboxTagField()
        }

        matchingAlgorithmField()

        if hasMoreFields {
            matchingPatternField()
            matchingIsInsensitiveField()
        }
    }

    @ViewBuilder
    private func isInboxTagField() -> some View {
        Field {
            Toggle(isOn: $store.input.isInboxTag, label: {
                Text(.inboxTag)
                    .lineLimit(1)
            })
            .accessibilityLabel(.inboxTag)
            .onTapGesture { store.input.isInboxTag.toggle() }
        }
        .tint(Color.m3Primary)
    }

    @ViewBuilder
    private func matchingAlgorithmField() -> some View {
        MenuField(
            title: .matchingAlgorithm,
            value: $store.input.matchingAlgorithm
        )
    }

    @ViewBuilder
    private func matchingIsInsensitiveField() -> some View {
        Field {
            Toggle(isOn: $store.input.isInsensitive, label: {
                Text(.caseInsensitive)
                    .lineLimit(1)
            })
            .onTapGesture { store.input.isInsensitive.toggle() }
        }
        .tint(Color.m3Primary)
    }

    @ViewBuilder
    private func matchingPatternField() -> some View {
        Field(.match) {
            TextField(String(localized: .match), text: $store.input.match.value)
                .textFieldStyle(.plain)
        }
        .state($store.input.match)
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
            ForEach(TagFormSection.allCases, id: \.self) {
                Text($0.description)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
    }

    @State
    private var color = Color.clear

    private var hasMoreFields: Bool {
        ![MatchingAlgorithm]([
            .none,
            .automatic
        ]).contains(store.input.matchingAlgorithm)
    }
}

#Preview {
    TagFormView(
        store: Store(
            initialState: .testValue(),
            reducer: {
                TagFormReducer()
            }
        )
    )
}
