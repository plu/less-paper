import ApiInterface
import Components
import SwiftUI

public extension View {

    func tag(
        tag: Tag,
        font: Font = .caption
    ) -> some View {
        capsule(
            backgroundColor: Color(hex: tag.color),
            font: font,
            foregroundColor: Color(hex: tag.textColor)
        )
    }
}
