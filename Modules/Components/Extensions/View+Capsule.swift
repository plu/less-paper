import DesignTokens
import SwiftUI

struct CapsuleModifier: ViewModifier {

    let backgroundColor: Color

    let font: Font

    let foregroundColor: Color

    let padding: EdgeInsets

    func body(content: Content) -> some View {
        content
            .padding(.top, padding.top)
            .padding(.bottom, padding.bottom)
            .padding(.leading, padding.leading)
            .padding(.trailing, padding.trailing)
            .background(backgroundColor)
            .foregroundColor(foregroundColor)
            .lineLimit(1)
            .font(font)
            .fontWeight(.medium)
            .clipShape(Capsule())
    }
}

public extension View {

    func capsule(
        backgroundColor: Color = .m3SurfaceContainer,
        font: Font = .subheadline,
        foregroundColor: Color = .m3OnSurface,
        padding: EdgeInsets = .init(top: .x2, leading: .x3, bottom: .x2, trailing: .x3)
    ) -> some View {
        modifier(CapsuleModifier(
            backgroundColor: backgroundColor,
            font: font,
            foregroundColor: foregroundColor,
            padding: padding
        ))
    }
}
