import Components
import ComposableArchitecture
import SwiftUI

@ViewAction(for: MfaFormReducer.self)
public struct MfaFormView: View {
    public var body: some View {
        Sheet {
            SheetHeader(
                title: .mfaCodeRequiredTitle,
                left: {
                    SheetCloseButton {
                        send(.closeButtonTapped)
                    }
                }
            )
        } content: {
            formView()
        } bottom: {
            buttons()
        }
        .interactiveDismissDisabled()
    }

    public init(store: StoreOf<MfaFormReducer>) {
        self.store = store
    }

    @Bindable
    public var store: StoreOf<MfaFormReducer>

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
                send(.submitButtonTapped)
            } label: {
                Text(.save)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.primary())
            .disabled(store.mfaCode.isEmpty)
        }
    }

    @ViewBuilder
    private func formView() -> some View {
        VStack(spacing: .x4) {
            Field(.mfaCode) {
                TextField(String(localized: .mfaCode), text: $store.mfaCode)
                    .focused($focus, equals: .code)
                    .textContentType(.oneTimeCode)
                    .textFieldStyle(.plain)
            }
            .accessibilityLabel(.alias)
            .onTapGesture { focus = .code }

            Text(.mfaCodeRequiredInfo)
                .font(.footnote)
                .foregroundStyle(Color.m3Outline)
        }
    }

    @FocusState
    private var focus: MfaFormField?
}
