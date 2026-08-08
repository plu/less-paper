import SwiftUI

struct FieldStateModifier<Value: Equatable & Sendable>: ViewModifier {

    @Binding
    var state: FieldState<Value>

    func body(content: Content) -> some View {
        content

            .focused($focused)

            .onChange(of: state.focused) { _, newValue in
                focused = newValue
            }

            .onChange(of: focused) { _, newValue in
                state.focused = newValue
                if newValue {
                    withAnimation(.snappy) {
                        state.error = nil
                    }
                }
            }

            .onChange(of: state.value) {
                withAnimation(.snappy) {
                    state.error = nil
                }
            }

            .onTapGesture {
                state.focused = true
            }

            .onAppear {
                focused = state.focused
            }

            .onDisappear {
                state.focused = false
            }
    }

    @FocusState
    private var focused: Bool
}
