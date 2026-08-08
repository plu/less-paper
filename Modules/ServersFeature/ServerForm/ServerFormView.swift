import ApiInterface
import Components
import ComposableArchitecture
import SwiftUI

@ViewAction(for: ServerFormReducer.self)
public struct ServerFormView: View {

    public var body: some View {
        Sheet {
            SheetHeader(
                title: .createServer,
                left: {
                    Button {
                        send(.closeButtonTapped)
                    } label: {
                        Image(systemName: "xmark")
                            .accessibilityLabel(.close)
                    }
                }
            )
        } content: {
            VStack(spacing: .x4) {
                sectionPicker()
                switch store.section {
                case .form:
                    formView()
                case .advanced:
                    advancedSection()
                }
            }
        } bottom: {
            buttons()
        }
        .sheet(
            item: $store.scope(
                state: \.destination?.mfaForm,
                action: \.destination.mfaForm
            )
        ) { store in
            MfaFormView(store: store)
                .presentationDetents([.medium])
        }
    }

    public init(store: StoreOf<ServerFormReducer>) {
        self.store = store
    }

    @Bindable
    public var store: StoreOf<ServerFormReducer>

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
            .disabled(!store.input.isValid)
        }
    }

    @ViewBuilder
    private func aliasField() -> some View {
        Field(.alias) {
            TextField(String(localized: .alias), text: $store.input.alias)
                .focused($focus, equals: .alias)
                .textFieldStyle(.plain)
        }
        .accessibilityLabel(.alias)
        .onTapGesture { focus = .alias }
    }

    @ViewBuilder
    private func passwordField() -> some View {
        Field(.password) {
            SecureField(String(localized: .password), text: $store.input.password)
                .focused($focus, equals: .password)
                .textFieldStyle(.plain)
        }
        .accessibilityLabel(.password)
        .onTapGesture { focus = .password }
    }

    @ViewBuilder
    private func urlField() -> some View {
        URLField(
            title: .url,
            url: $store.input.url
        )
    }

    @ViewBuilder
    private func usernameField() -> some View {
        Field(.username) {
            TextField(String(localized: .username), text: $store.input.username)
                .focused($focus, equals: .username)
                .textFieldStyle(.plain)
                .textInputAutocapitalization(.never)
        }
        .accessibilityLabel(.username)
        .onTapGesture { focus = .username }
    }

    @ViewBuilder
    private func formView() -> some View {
        VStack(spacing: .x4) {
            urlField()
            usernameField()
            passwordField()
            aliasField()
        }
    }

    @ViewBuilder
    private func sectionPicker() -> some View {
        Picker("", selection: $store.section) {
            ForEach(ServerFormSection.allCases, id: \.self) {
                Text($0.description)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
    }

    @ViewBuilder
    private func advancedSection() -> some View {
        VStack(alignment: .leading, spacing: .x0) {
            Text(.httpHeaders)
                .fontWeight(.semibold)
                .padding(.horizontal)

            VStack(spacing: .x4) {
                ForEach(store.input.headers) { header in
                    headerRow(header)
                    if header.id != store.input.headers.last?.id {
                        Divider()
                    }
                }

                Button {
                    send(.addHeaderButtonTapped)
                } label: {
                    Label(String(localized: .addHeader), systemImage: "plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.secondary())
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: Constants.cornerRadius).foregroundStyle(Color.m3SurfaceContainer))
        }
    }

    @ViewBuilder
    private func headerRow(_ header: HTTPHeader) -> some View {
        VStack(alignment: .leading, spacing: .x2) {
            HStack {
                Spacer()

                Button {
                    send(.deleteHeaderButtonTapped(header.id))
                } label: {
                    Image(systemName: "trash")
                        .foregroundColor(.m3Error)
                }
                .accessibilityLabel(.deleteHeader)
            }

            Field(.headerName) {
                TextField(String(localized: .headerName), text: headerNameBinding(header.id))
                    .textFieldStyle(.plain)
                    .textInputAutocapitalization(.never)
            }

            Field(.headerValue) {
                TextField(String(localized: .headerValue), text: headerValueBinding(header.id))
                    .textFieldStyle(.plain)
            }
        }
    }

    private func headerNameBinding(_ id: HTTPHeader.ID) -> Binding<String> {
        Binding(
            get: { store.input.headers[id: id]?.name ?? "" },
            set: { send(.headerNameChanged(id, $0)) }
        )
    }

    private func headerValueBinding(_ id: HTTPHeader.ID) -> Binding<String> {
        Binding(
            get: { store.input.headers[id: id]?.value ?? "" },
            set: { send(.headerValueChanged(id, $0)) }
        )
    }

    @FocusState
    private var focus: ServerFormField?
}

#Preview {
    ServerFormView(
        store: Store(
            initialState: .testValue(),
            reducer: {
                ServerFormReducer()
            }
        )
    )
}
