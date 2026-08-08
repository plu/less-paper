import SwiftUI

public extension View {

    @ViewBuilder
    func readSize(into size: Binding<CGSize>) -> some View {
        overlay(
            GeometryReader { geometry in
                Color
                    .clear
                    .preference(
                        key: SizePreferenceKey.self,
                        value: geometry.size
                    )
            }.allowsHitTesting(false)
        )
        .onPreferenceChange(SizePreferenceKey.self) {
            size.wrappedValue = $0
        }
    }
}

private struct SizePreferenceKey: PreferenceKey {

    static let defaultValue: CGSize = .zero

    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}
