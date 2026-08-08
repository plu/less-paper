import SwiftUI

public extension View {

    @available(iOS 14, macOS 11, tvOS 14, watchOS 7, *)
    func bind(
        _ modelValue: Binding<String>, to viewValue: Binding<Color>
    ) -> some View {
        modifier(
            BindColorViewModifier(
                modelValue: modelValue,
                viewValue: viewValue
            )
        )
    }
}

private struct BindColorViewModifier: ViewModifier {

    let modelValue: Binding<String>

    let viewValue: Binding<Color>

    func body(content: Content) -> some View {
        content
            .onAppear {
                guard !hasAppeared else {
                    return
                }

                hasAppeared = true

                guard viewValue.wrappedValue.hexValue != modelValue.wrappedValue else {
                    return
                }

                viewValue.wrappedValue = Color(hex: modelValue.wrappedValue)
            }
            .onChange(of: modelValue.wrappedValue) {
                if viewValue.wrappedValue.hexValue != modelValue.wrappedValue {
                    viewValue.wrappedValue = Color(hex: modelValue.wrappedValue)
                }
            }
            .onChange(of: viewValue.wrappedValue) {
                if viewValue.wrappedValue.hexValue != modelValue.wrappedValue {
                    modelValue.wrappedValue = viewValue.wrappedValue.hexValue
                }
            }
    }

    @State
    private var hasAppeared = false
}
