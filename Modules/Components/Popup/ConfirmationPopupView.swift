import SwiftUI

public struct ConfirmationPopupView<Content: View>: View {
    public var body: some View {
        Sheet {
            Text(title)
        } content: {
            content
                .font(.body)
                .foregroundStyle(Color.m3OnSurface)
                .frame(
                    maxWidth: .infinity,
                    maxHeight: .infinity,
                    alignment: .topLeading
                )
        } bottom: {
            AdaptiveStack {
                Button {
                    cancel()
                } label: {
                    Text(cancelTitle)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.secondary())
                .disabled(isLoading)
                .frame(maxWidth: .infinity)

                Button {
                    confirmButtonTapped()
                } label: {
                    Text(confirmTitle)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(confirmButtonStyle)
            }
        }
        .background(Color.m3Surface)
        .clipShape(RoundedRectangle(cornerRadius: Constants.cornerRadius))
        .padding(.x4)
        .frame(maxWidth: 600)
    }

    /**
     * Creates a confirmation popup with custom content.
     *
     * - Parameters:
     *   - title: The title shown in the popup's header bar
     *   - confirmTitle: The confirm button's title, defaulting to the shared "Confirm" string
     *   - cancelTitle: The cancel button's title, defaulting to the shared "Cancel" string
     *   - isDestructive: Whether the confirm button uses the critical style
     *   - submit: Optional async work run while the confirm button shows a spinner, before `confirm`
     *   - cancel: Called when the cancel button is tapped
     *   - confirm: Called when the confirm button is tapped, after `submit` has finished
     *   - content: The popup's body
     */
    public init(
        title: LocalizedStringResource,
        confirmTitle: LocalizedStringResource? = nil,
        cancelTitle: LocalizedStringResource? = nil,
        isDestructive: Bool = false,
        submit: (@Sendable () async -> Void)? = nil,
        cancel: @escaping () -> Void,
        confirm: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.confirmTitle = confirmTitle ?? .confirm
        self.cancelTitle = cancelTitle ?? .cancel
        self.isDestructive = isDestructive
        self.submit = submit
        self.cancel = cancel
        self.confirm = confirm
        self.content = content()
    }

    private let title: LocalizedStringResource
    private let confirmTitle: LocalizedStringResource
    private let cancelTitle: LocalizedStringResource
    private let isDestructive: Bool
    private let submit: (@Sendable () async -> Void)?
    private let cancel: () -> Void
    private let confirm: () -> Void
    private let content: Content

    @State
    private var isLoading = false

    private var confirmButtonStyle: ButtonStyle {
        isDestructive
            ? .critical(isLoading: $isLoading)
            : .primary(isLoading: $isLoading)
    }

    private func confirmButtonTapped() {
        guard let submit else {
            confirm()
            return
        }

        Task {
            isLoading = true
            await submit()
            isLoading = false
            confirm()
        }
    }
}

public extension ConfirmationPopupView where Content == Text {

    /**
     * Creates a confirmation popup showing a single message.
     *
     * - Parameters:
     *   - title: The title shown in the popup's header bar
     *   - message: The message shown in the popup's body
     *   - confirmTitle: The confirm button's title, defaulting to the shared "Confirm" string
     *   - cancelTitle: The cancel button's title, defaulting to the shared "Cancel" string
     *   - isDestructive: Whether the confirm button uses the critical style
     *   - submit: Optional async work run while the confirm button shows a spinner, before `confirm`
     *   - cancel: Called when the cancel button is tapped
     *   - confirm: Called when the confirm button is tapped, after `submit` has finished
     */
    init(
        title: LocalizedStringResource,
        message: LocalizedStringResource,
        confirmTitle: LocalizedStringResource? = nil,
        cancelTitle: LocalizedStringResource? = nil,
        isDestructive: Bool = false,
        submit: (@Sendable () async -> Void)? = nil,
        cancel: @escaping () -> Void,
        confirm: @escaping () -> Void
    ) {
        self.init(
            title: title,
            confirmTitle: confirmTitle,
            cancelTitle: cancelTitle,
            isDestructive: isDestructive,
            submit: submit,
            cancel: cancel,
            confirm: confirm,
            content: { Text(message) }
        )
    }
}
